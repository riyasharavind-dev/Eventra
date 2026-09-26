import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "https://esm.sh/jose@5";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get(
  "SUPABASE_SERVICE_ROLE_KEY",
)!;

const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID")!;
const FIREBASE_CLIENT_EMAIL = Deno.env.get("FIREBASE_CLIENT_EMAIL")!;
const FIREBASE_PRIVATE_KEY_B64 = Deno.env.get(
  "FIREBASE_PRIVATE_KEY_B64",
)!;

const supabase = createClient(
  SUPABASE_URL,
  SUPABASE_SERVICE_ROLE_KEY,
);

function decodeBase64(value: string): string {
  const binary = atob(value);

  const bytes = Uint8Array.from(
    binary,
    (char) => char.charCodeAt(0),
  );

  return new TextDecoder().decode(bytes);
}

async function getFirebaseAccessToken(): Promise<string> {
  if (!FIREBASE_PRIVATE_KEY_B64) {
    throw new Error(
      "FIREBASE_PRIVATE_KEY_B64 environment variable is missing",
    );
  }

  const privateKey = decodeBase64(
    FIREBASE_PRIVATE_KEY_B64,
  );

  if (!privateKey.includes("BEGIN PRIVATE KEY")) {
    throw new Error(
      "Decoded Firebase private key is invalid",
    );
  }

  const cryptoKey = await importPKCS8(
    privateKey,
    "RS256",
  );

  const now = Math.floor(Date.now() / 1000);

  const jwt = await new SignJWT({
    scope:
      "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({
      alg: "RS256",
      typ: "JWT",
    })
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .setIssuer(FIREBASE_CLIENT_EMAIL)
    .setAudience(
      "https://oauth2.googleapis.com/token",
    )
    .sign(cryptoKey);

  const tokenResponse = await fetch(
    "https://oauth2.googleapis.com/token",
    {
      method: "POST",
      headers: {
        "Content-Type":
          "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        grant_type:
          "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt,
      }),
    },
  );

  const tokenData = await tokenResponse.json();

  if (!tokenResponse.ok) {
    throw new Error(
      `Firebase OAuth error: ${JSON.stringify(tokenData)}`,
    );
  }

  if (!tokenData.access_token) {
    throw new Error(
      "Firebase OAuth response did not contain access_token",
    );
  }

  return tokenData.access_token;
}

Deno.serve(async (req) => {
  try {
    const body = await req.json();

    const record = body?.record;

    if (!record?.id) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Missing booking record",
        }),
        {
          status: 400,
          headers: {
            "Content-Type": "application/json",
          },
        },
      );
    }

    const bookingId = record.id;
    const vendorId = record.vendor_id;
    const serviceId = record.service_id;

    if (!vendorId) {
      throw new Error(
        "Booking does not contain vendor_id",
      );
    }

    if (!serviceId) {
      throw new Error(
        "Booking does not contain service_id",
      );
    }

    const { data: tokens, error: tokenError } =
      await supabase
        .from("fcm_tokens")
        .select("token")
        .eq("user_id", vendorId);

    if (tokenError) {
      throw new Error(
        `Failed to get FCM tokens: ${tokenError.message}`,
      );
    }

    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          booking_id: bookingId,
          vendor_id: vendorId,
          notifications_sent: 0,
          message: "No FCM token found for vendor",
        }),
        {
          status: 200,
          headers: {
            "Content-Type": "application/json",
          },
        },
      );
    }

    const { data: service, error: serviceError } =
      await supabase
        .from("services")
        .select("name")
        .eq("id", serviceId)
        .maybeSingle();

    if (serviceError) {
      throw new Error(
        `Failed to get service: ${serviceError.message}`,
      );
    }

    const serviceName =
      service?.name ?? "your service";

    const accessToken =
      await getFirebaseAccessToken();

    const results = [];

    for (const tokenRow of tokens) {
      const fcmToken = tokenRow.token;

      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
        {
          method: "POST",
          headers: {
            "Authorization":
              `Bearer ${accessToken}`,
            "Content-Type":
              "application/json",
          },
          body: JSON.stringify({
            message: {
              token: fcmToken,

              notification: {
                title: "New Booking Received",
                body:
                  `You received a new booking for ${serviceName}.`,
              },

              data: {
                type: "new_booking",
                booking_id: String(bookingId),
                vendor_id: String(vendorId),
                service_id: String(serviceId),
              },

              android: {
                priority: "high",
                notification: {
                  sound: "default",
                },
              },
            },
          }),
        },
      );

      const responseText =
        await response.text();

      if (!response.ok) {
        results.push({
          success: false,
          token:
            fcmToken.substring(0, 12) + "...",
          error: responseText,
        });
      } else {
        results.push({
          success: true,
        });
      }
    }

    const sentCount =
      results.filter(
        (result) => result.success,
      ).length;

    return new Response(
      JSON.stringify({
        success: true,
        booking_id: bookingId,
        vendor_id: vendorId,
        notifications_sent: sentCount,
        results,
      }),
      {
        status: 200,
        headers: {
          "Content-Type":
            "application/json",
        },
      },
    );
  } catch (error) {
    console.error(
      "send-booking-notification error:",
      error,
    );

    return new Response(
      JSON.stringify({
        success: false,
        error:
          error instanceof Error
            ? error.message
            : String(error),
      }),
      {
        status: 500,
        headers: {
          "Content-Type":
            "application/json",
        },
      },
    );
  }
});