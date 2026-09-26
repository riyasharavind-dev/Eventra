import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "supabase";
import { importPKCS8, SignJWT } from "jose";

const SUPABASE_URL =
  Deno.env.get("SUPABASE_URL")!;

const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const FIREBASE_PROJECT_ID =
  Deno.env.get("FIREBASE_PROJECT_ID")!;

const FIREBASE_CLIENT_EMAIL =
  Deno.env.get("FIREBASE_CLIENT_EMAIL")!;

const FIREBASE_PRIVATE_KEY_B64 =
  Deno.env.get("FIREBASE_PRIVATE_KEY_B64")!;

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
      "FIREBASE_PRIVATE_KEY_B64 is missing",
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

  const response = await fetch(
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

  const data = await response.json();

  if (!response.ok) {
    throw new Error(
      `Firebase OAuth error: ${JSON.stringify(data)}`,
    );
  }

  if (!data.access_token) {
    throw new Error(
      "Firebase OAuth response did not contain access_token",
    );
  }

  return data.access_token;
}

type BookingRecord = {
  id?: string;
  customer_id?: string;
  vendor_id?: string;
  service_id?: string;
  status?: string;
};

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Method not allowed",
        }),
        {
          status: 405,
          headers: {
            "Content-Type":
              "application/json",
          },
        },
      );
    }

    const body = await req.json();

    const record =
      body?.record as BookingRecord | undefined;

    if (!record?.id) {
      throw new Error(
        "Missing booking record",
      );
    }

    const bookingId = record.id;
    const customerId = record.customer_id;
    const status = record.status;

    if (!customerId) {
      throw new Error(
        "Booking does not contain customer_id",
      );
    }

    if (
      status !== "accepted" &&
      status !== "rejected"
    ) {
      return new Response(
        JSON.stringify({
          success: true,
          booking_id: bookingId,
          status,
          notifications_sent: 0,
          message:
            "Status does not require notification",
        }),
        {
          status: 200,
          headers: {
            "Content-Type":
              "application/json",
          },
        },
      );
    }

    const { data: tokens, error: tokenError } =
      await supabase
        .from("fcm_tokens")
        .select("token")
        .eq("user_id", customerId);

    if (tokenError) {
      throw new Error(
        `Failed to get customer tokens: ${tokenError.message}`,
      );
    }

    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          booking_id: bookingId,
          customer_id: customerId,
          status,
          notifications_sent: 0,
          message:
            "No FCM token found for customer",
        }),
        {
          status: 200,
          headers: {
            "Content-Type":
              "application/json",
          },
        },
      );
    }

    const accessToken =
      await getFirebaseAccessToken();

    const title =
      status === "accepted"
        ? "Booking Accepted"
        : "Booking Rejected";

    const message =
      status === "accepted"
        ? "Your booking request has been accepted by the vendor."
        : "Your booking request has been rejected by the vendor.";

    const notificationType =
      status === "accepted"
        ? "booking_accepted"
        : "booking_rejected";

    const results: Array<{
      success: boolean;
      error?: string;
    }> = [];

    for (const tokenRow of tokens) {
      const fcmResponse = await fetch(
        `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization:
              `Bearer ${accessToken}`,
            "Content-Type":
              "application/json",
          },
          body: JSON.stringify({
            message: {
              token: tokenRow.token,

              notification: {
                title,
                body: message,
              },

              data: {
                type: notificationType,
                booking_id: String(
                  bookingId,
                ),
                status: String(status),
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
        await fcmResponse.text();

      if (!fcmResponse.ok) {
        results.push({
          success: false,
          error: responseText,
        });
      } else {
        results.push({
          success: true,
        });
      }
    }

    const notificationsSent =
      results.filter(
        (result) => result.success,
      ).length;

    return new Response(
      JSON.stringify({
        success: true,
        booking_id: bookingId,
        customer_id: customerId,
        status,
        notifications_sent:
          notificationsSent,
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
      "Booking status notification error:",
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