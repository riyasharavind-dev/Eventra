# Eventor admin team access

Implemented for `https://eventor-admin.onrender.com`.

## Owner workflow

Open **Team & Access → Invite Staff**. Enter an existing work email, name and role. Owners and Admins must enroll a time-based authenticator before accessing protected admin data. First enrollment displays a locally rendered QR code, with a selectable manual setup key and Copy button underneath; subsequent logins ask for its six-digit code. Keep the authenticator account backed up securely.

- **Owner:** team management, infrastructure and all operational modules.
- **Admin:** operational modules; no team, global audit, device-token or infrastructure access.
- **Staff:** only selected modules, with separate View/Edit permissions.
- **Viewer:** only selected modules, with read access.

Edit a member to change roles, module permissions or suspend/reactivate access. The last active owner cannot be suspended, deleted or demoted. Changes use a revision check, and role/permission operations are audited. Existing sessions cannot bypass suspended membership or newly revoked module permissions. Restricted users cannot bypass scope through dashboard, feed or storage inventory endpoints. Private media reads and new uploads are also scoped. New admin media uses `admins/<actor>/<module>/...`.

Invitations expire after seven days. Owners can resend or revoke them. Email tokens are validated by Supabase Auth; activation additionally checks the linked user, confirmed email, invitation status and expiry. Pending invitations confer no admin permissions. Resending an existing Auth invitee uses a password recovery email targeting the setup flow. Vendor/customer accounts must use a separate work email for staff access.

## Email configuration still required

There is no company email provider or verified sender yet. **Company Email Settings** saves sender name/email, reply-to preference and provider name. These are preferences, not SMTP credentials and not proof of domain verification. This screen does not create email inboxes. Create/manage real company mailboxes with your chosen email provider, then invite those addresses here.

An owner must:

1. Verify the sending domain with an SMTP/email provider.
2. Configure **Supabase → Authentication → Email → SMTP** with its host, port, username, password and matching sender address/name. Store credentials only in Supabase, never Flutter source or this settings table.
3. Configure the provider/template reply-to to match the saved preference if supported. Preferences do not automatically change Supabase sender settings.
4. Ensure Invite User and Reset Password templates retain Supabase's verification link and `RedirectTo` behavior. Invite links target `https://eventor-admin.onrender.com/?auth_action=setup`; recovery targets `https://eventor-admin.onrender.com/?auth_action=recovery`.
5. After SMTP is verified, enable invitation sending from the project root:

   ```powershell
   .\node_modules\.bin\supabase.cmd secrets set TEAM_EMAIL_ENABLED=true --project-ref hrrimcxwpfdikbmywznf
   ```

6. Send one genuine staff invitation and test setup, sign-out/login, forgotten password, expired-link handling and revocation end to end.

Until step 5, the invitation backend saves the pending invitation and explicitly reports **configuration pending**. It does not claim an email was sent. Forgot Password uses Supabase Auth and also needs working SMTP for real delivery; its success text does not reveal account existence. Auth enforces email token expiry/use and email request limits. Invitation requests additionally have a one-minute resend delay and a 20/hour per-owner request limit.

The three exact Render admin callback URLs were added to the hosted allowlist. Existing Auth settings were preserved; the project-wide Site URL was not changed because customer/vendor apps share this backend. TOTP enrollment/verification were already enabled.

## Deployment

Deploy the updated `admin` frontend to Render before using the new flows. The old frontend does not include authenticator setup and cannot pass the new Owner/Admin data-access requirement. The production web build is `admin/build/web`; normal Render source deployment must build the updated source. A refresh or new private browser window may be needed after deployment.

The `admin-team-invite` Edge Function is deployed separately to Supabase. It validates the caller, then calls a database RPC that requires an active Owner at MFA assurance level 2. The privileged key exists only in the function's server environment. CORS allows the production Render origin. Local browser invitation testing should use a deliberately configured development origin; it is not enabled by a wildcard.

## Passwords and lost authenticators

Login includes **Forgot Password**. Click the email’s Reset password link to open New Password + Confirm Password directly. Saved passwords show a success confirmation and Back to login signs out the recovery session. Invite links open Set Your Password. The UI requires 12 characters and matching confirmation. If an authenticator is already connected, its six-digit code is entered on the same password form before saving. Email reset cannot bypass MFA. Global customer/vendor password policies were not changed by this rollout.

There are no app-managed backup codes. If a device is lost, an authorized Supabase project operator must verify the person's identity out of band and remove only that user's lost MFA factor through trusted Supabase administration. The user can then re-enroll. A sole owner needs a trusted project operator for this recovery; there is no public bypass. Keep project access recovery available.

## Database and verification

- Migration: `admin/sql/20_team_access.sql`, applied live.
- Private, RLS-enabled tables: `eventra_admin.team_invitations`, `team_permissions`, `company_email_settings`.
- Generic admin-profile editing and the legacy grant-access endpoint are disabled; use the audited Team workflow.
- Legacy admin RPC implementations are private; public wrappers enforce module/role access. The owner-only database inventory includes sanitized read-only browsing for the three new tables.
- Regression assertions: `admin/sql/tests/team_access_test.sql` and updated existing security/connection tests. Fixtures and writes roll back; no real invitations/emails are used by tests.
- Flutter tests cover invitation View/Edit scope, configuration-pending feedback and password validation.
- New screens are in `admin/lib/screens/extended/`.

Real email delivery and a real authenticator sign-in have not been exercised with a staff account because no SMTP provider or staff address was supplied. Automated database checks cover the backend MFA/permission requirements; release web compilation covers the frontend build.

### Simplified recovery implementation

New reset requests use a separate, non-persistent implicit-flow Auth sender so email links can be opened on another browser/device without a locally stored PKCE verifier. Normal sign-in keeps its PKCE configuration. The web session gate verifies callback credentials once before rendering a reset form, catches expired links even when another session exists, removes token parameters from browser history, and retains only the reset screen hint until saving. Old PKCE emails still require their original browser; request a new reset email after deployment. No shared Auth settings, database permission changes or email template changes were required. Automated tests cover callback parsing, required inline MFA, success/login and existing admin features; real inbox delivery was not exercised in this change.
