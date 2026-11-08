# Customer and vendor account separation

Customer and vendor use separate Auth UIDs and immutable public.users roles. Their profiles, bookings, permissions and private realtime audiences stay tied to those UIDs. Accounts are never merged by phone or email. Existing email/password login remains in use; because one Supabase Auth project has unique email identities, separate accounts currently need different emails.

Migration 26 adds a private, RLS-enabled verified-phone registry with unique (account_role, phone_e164) and one binding per UID. The same canonical +91 number can belong to a customer UID and a different vendor UID. Two customer accounts cannot claim the same verified number, nor two vendor accounts. Existing contact numbers are NOT backfilled, verified, deduplicated or deleted. Editing a contact number does not change a login binding.

Both app auth repositories validate against get_my_app_account using a fixed app role. The backend rejects wrong-role, deleted and banned accounts. Clients can read only their own verified mapping; they cannot enumerate or write bindings. Database guards reject account role/ID conversion and mismatched profiles. Admin MFA and staff permissions are unchanged.

## SMS provider pending

This is account/mapping preparation, NOT live phone OTP login. No OTP UI, SMS provider, test bypass, native Auth phone updates or password recovery changes are enabled. A shared Supabase Auth phone sign-in cannot represent two independent accounts with the same phone. Do not call signInWithOtp(phone: ...) to implement this design.

A future trusted OTP broker must verify a short-lived, single-use provider proof bound to the intended app, phone, operation and requesting session. Linking requires reauthentication of the existing email/password account; it must not create a replacement UID. Only after verification may the server call bind_verified_app_phone. resolve_verified_app_phone is service-role-only and returns an active UID for an exact app + phone; it does not grant a session. Session issuance/recovery, anti-enumeration responses, per-phone/IP rate limits, CAPTCHA, proof consumption, audit retention and phone-recycling recovery must be completed with the chosen provider before enabling phone login. Never ship service credentials in Flutter.

The trusted bind/resolve/remove RPCs do not themselves validate SMS proofs; access is restricted to the service role. The mapping registry is not a generic admin-editable CRUD module because manual edits would bypass verification. No SMS spend or provider registration is required for this migration.
