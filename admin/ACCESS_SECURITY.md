# Eventor access security baseline

Apply `sql/18_access_security.sql` after the existing Eventor migrations. The migration is transactional and preserves application records. It deliberately replaces old public-schema and Storage object policies rather than combining restrictive rules with permissive legacy policies.

All 35 current public tables have RLS enabled. Anonymous clients can read active marketplace records and published content, and use explicitly allowlisted discovery/review RPCs. Profiles, customer addresses, device tokens, bookings, verification metadata, support, moderation, admin authority and audit data are not publicly enumerable.

Authenticated customers and vendors can edit their own permitted profile columns. Identity email, account type, record ownership, approval decisions and admin membership are server-owned. Business/service mutations require vendor ownership. The admin panel continues using permission-checked RPCs and owner/admin/viewer roles; it does not receive unrestricted client table writes.

Booking creation requires a customer account, matching customer/vendor/service ownership, an active service, pending status and the current server-side base price. The server derives the event type. Current checkout books one base unit; a future quantity or custom quote flow must calculate its price on the server. Status changes, private notes, history and reviews use their existing guarded RPCs. Services with bookings cannot be deleted through the vendor deletion RPC; deactivate them instead. Vendor source uses `delete_vendor_service` before attempting gallery cleanup.

Storage writes are restricted to the authenticated account's paths or authorized admin placements. Public image buckets intentionally retain public image downloads; verification/support buckets remain private. Profile uploads have a 5 MB image MIME allowlist. Direct public bucket creation/editing and anonymous uploads/deletes are revoked. Existing media objects are not deleted.

Four published-content views use `security_invoker`. Public function execution is allowlisted; internal trigger/notification functions cannot be called as public RPCs. Future objects created by `postgres` do not automatically receive public client grants from the defaults configured by this migration. New migrations must explicitly enable RLS and declare grants/policies for new tables.

## Validation

Run `sql/tests/access_security_test.sql` using a trusted SQL connection. It creates synthetic accounts, disables outbound booking notification triggers only inside its transaction, simulates anonymous/two-vendor/two-customer/owner/viewer requests, and rolls back everything. It does not require any real customer credentials. The Storage API's delete-guard setting is transaction-local and used only to exercise RLS against synthetic object metadata.

Coverage includes 55 assertions: public discovery, private-data denial, cross-account edits, identity/admin escalation, verification self-approval, booking owner/price/status integrity, guarded booking decisions, safe service deletion, token ownership, storage paths, viewer restrictions and owner/admin compatibility.

This is a tested database/Storage access baseline, not a guarantee against every application or infrastructure attack. Auth password/MFA settings, rate limits, notification webhook authentication, dependency updates and release signing require their own review. Re-run access tests when changing schema, RPCs, storage paths or checkout pricing.
