import { createClient } from "npm:@supabase/supabase-js@2.99.1";

const cors = {
  "Access-Control-Allow-Origin": "https://eventor-admin.onrender.com",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};
const reply = (status: number, data: unknown) => new Response(JSON.stringify(data), {
  status, headers: { ...cors, "Content-Type": "application/json" },
});

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "POST required" });
  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return reply(401, { error: "Sign in again" });
  const url = Deno.env.get("SUPABASE_URL")!;
  const caller = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const server = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { error: userError } = await caller.auth.getUser();
  if (userError) return reply(401, { error: "Sign in again" });
  let input;
  try {
    if (Number(req.headers.get("Content-Length") ?? 0) > 16000) return reply(413, { error: "Request too large" });
    input = await req.json();
  } catch { return reply(400, { error: "Invalid request" }); }
  const { data: invitation, error } = await caller.rpc("admin_team_invite_prepare", {
    p_email: input.email, p_name: input.name, p_level: input.level,
    p_permissions: input.permissions ?? {}, p_resend: input.resend === true,
  });
  if (error) return reply(403, { error: error.message });
  // Sender preferences alone cannot prove DNS/SMTP verification. Enable only after
  // configuring and testing Supabase Auth SMTP in the project dashboard.
  if (!invitation.email_configured || Deno.env.get("TEAM_EMAIL_ENABLED") !== "true") {
    await server.rpc("admin_team_invite_result", { p_id: invitation.id, p_failed: true });
    return reply(200, { delivery: "pending_configuration", message: "Invitation saved. Configure and verify company SMTP before sending." });
  }
  const redirectTo = `${invitation.admin_url}/?auth_action=setup`;
  let userId = invitation.user_id;
  if (!userId) {
    const result = await server.auth.admin.inviteUserByEmail(invitation.email, {
      data: { name: invitation.name, role: "admin" }, redirectTo,
    });
    if (result.error) {
      await server.rpc("admin_team_invite_result", { p_id: invitation.id, p_failed: true });
      return reply(200, { delivery: "failed", message: "Email could not be sent. Check SMTP/Auth delivery logs, then resend." });
    }
    userId = result.data.user.id;
  }
  const attached = await server.rpc("admin_team_invite_result", { p_id: invitation.id, p_user_id: userId, p_failed: false });
  if (attached.error) return reply(500, { error: "Could not attach invitation. Retry from Team & Access." });
  // Existing pending invitees receive a recovery link to the same setup screen.
  // Auth validates its single-use token; activation independently checks pending
  // invitation state, verified email, expiry and user ID in the database.
  if (invitation.user_id) {
    const result = await server.auth.resetPasswordForEmail(invitation.email, { redirectTo });
    if (result.error) {
      await server.rpc("admin_team_invite_result", { p_id: invitation.id, p_failed: true });
      return reply(200, { delivery: "failed", message: "Email could not be sent. Check SMTP/Auth delivery logs, then resend." });
    }
  }
  return reply(200, { delivery: "sent", message: "Invitation email sent." });
});
