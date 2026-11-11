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

Deno.serve(async (req: Request) => {
 const json=(value:unknown,status=200)=>new Response(JSON.stringify(value),{status,headers:{"Content-Type":"application/json"}});
 if(req.method!=="POST")return json({error:"Method not allowed"},405);
 let eventId:string|undefined;
 try {
  const body=await req.json();eventId=body?.event_id;
  if(typeof eventId!=="string"||!/^[0-9a-f-]{36}$/i.test(eventId))return json({error:"Invalid event"},400);
  // The client cannot create/read these IDs. Never trust record/customer/token data from HTTP.
  const {data:event,error}=await supabase.rpc("claim_booking_push",{p_id:eventId});
  if(error)throw error;
  if(!event?.id)return json({processed:false});
  const {data:tokens,error:tokenError}=await supabase.from("fcm_tokens").select("token").eq("user_id",event.customer_id);
  if(tokenError)throw tokenError;
  let retry=false,sent=0;
  if(tokens?.length){
   const accessToken=await getFirebaseAccessToken();
   for(const row of tokens){
    const response=await fetch(`https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,{
     method:"POST",headers:{Authorization:`Bearer ${accessToken}`,"Content-Type":"application/json"},
     body:JSON.stringify({message:{token:row.token,notification:{title:event.title,body:event.body},
      data:{type:event.event_type,booking_id:event.booking_id,event_id:event.id},
      android:{priority:"high",notification:{tag:event.booking_id,sound:"default"}},
      apns:{headers:{"apns-collapse-id":event.booking_id},payload:{aps:{sound:"default"}}}}})
    });
    if(response.ok){sent++;continue;}
    const result=await response.json();
    const unregistered=result?.error?.details?.some((d:{errorCode?:string})=>d.errorCode==="UNREGISTERED");
    if(unregistered)await supabase.from("fcm_tokens").delete().eq("token",row.token).eq("user_id",event.customer_id);
    else if(response.status===429||response.status>=500)retry=true;
    else console.error("FCM delivery rejected",response.status);
   }
  }
  const {error:updateError}=await supabase.from("booking_push_outbox").update({status:retry?"pending":"sent",sent_at:retry?null:new Date().toISOString()}).eq("id",eventId);
  if(updateError)throw updateError;
  return json({processed:true,sent});
 } catch(_error){
  if(eventId)await supabase.from("booking_push_outbox").update({status:"pending"}).eq("id",eventId).eq("status","processing");
  console.error("Booking push delivery failed");return json({error:"Delivery failed"},500);
 }
});
