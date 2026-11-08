# App-wide live data and loading

Migration applied to the linked database: `admin/sql/25_app_realtime.sql`.
Security/ownership/MFA checks: `admin/sql/tests/app_realtime_test.sql`.
Client lifecycle tests: `test/app_live_data_test.dart` in vendor, customer and admin.

## Data flow

Source tables keep their existing RLS/RPC rules. Trusted database triggers upsert `app_data_revisions(audience,dataset,version,changed_at)`. No original rows, names, booking details, review text, tickets, files, passwords or other private payloads enter this feed. Audiences are public catalogue, one authenticated identity, or active admin access (including required MFA). Clients have SELECT-only rights and cannot spoof signals or call internal publishers. The only newly published table is the revisions table; existing bookings/notification channels remain protected and now feed the same refresh scheduler.

The shared AppLiveData service uses the signed-in Supabase client, one shared revision channel, auth-aware reconnect generation checks, a small indexed snapshot for missed revisions, app-resume recovery, and a 45-second fallback when the socket is unavailable. Reconnect/resume also revalidates active data even if a prior HTTP read failed after receiving its revision. Socket events are small invalidation hints; actual records are always fetched through the original authorized repositories/RPCs.

LiveDataBinding batches changes in a bounded 300 ms window, serializes refreshes, retains changes arriving during a request, and retries propagated transient failures with bounded backoff. Continuous traffic cannot postpone refresh forever. Covered routes, inactive retained tabs and background apps keep dirty flags and defer reads until visible again. Disposal cancels scheduled work. Each screen still owns readable error/retry handling; cached data is retained where its existing view model supports it.

## Connected data surfaces

- Vendor dashboard/profile statistics, business lists/details, listings/details, bookings/details/calendar, customer reviews/rating summaries, notifications, support lists/conversations, legal/about content and social links.
- Customer home/editorial feed/recommendations, Explore, search results, service details (including current price/availability), bookings, reviews, profile summaries, saved-service card snapshots, support and legal/social content.
- Admin dashboard, module tables/detail records and related labels, support conversations, home-feed workspace, category/event/service/vendor/customer/banner lists, team/permission context and storage browser/inventory.
- Account suspension/role changes refresh access guards. Valid background revalidation does not remount the app or destroy an open form. Offline checks retry rather than treating a transport failure as revocation. Auth recovery/new-password flows keep their existing MFA and email-link handling.

Add/Edit inputs intentionally keep their draft while open. Read-only information refreshes, and changes received while a modal editor covers a page are applied on return. Existing server validation still resolves removed categories, stale pricing, ownership and revision conflicts when saving. A database change is not permission to overwrite a user's unsaved fields.

## Loading improvements

Main tabs mount only when first opened, then retain their state. Switching tabs does not automatically blank/refetch profiles. Independent listing/business/profile queries run in parallel; favorites refresh service details in bounded batches. Home reloads only the affected component, and a realtime editorial-feed refresh preserves the previously loaded section window. Search/category/status filters remain intact unless their selected entity disappears. No new mobile package was added and UI colours/layouts were preserved.

## Deployment and limits

Database changes are live. Updated frontend code must be rebuilt/installed; do a full app restart, because a hot reload does not rerun root initialization. The Render admin site needs a new deployment of this build before its browser receives the new client layer. This work does not itself publish a Git commit or Render deployment.

This is near-real-time while connected: delivery latency includes the bounded window, network and authorized data fetch. Offline changes appear after reconnect/resume, not while disconnected. Initial sign-in/loading and explicit error/retry states remain. Scheduled publication time windows still need their existing timed reconciliation/manual refresh; unchanged clock-based rules are not row mutations. High-concurrency/mobile battery/performance benchmarks and a physical two-device acceptance test are not established by unit tests or the wire probe. At larger scale, benchmark trigger/WAL fan-out and use batched invalidation/broadcast infrastructure as needed. The current Explore catalogue loader still loads its permitted catalogue; server-side category pagination is a separate future scaling improvement.

## Optional wire probe

From vendor: `dart run tool/realtime_probe.dart`. It subscribes using the configured public key and waits for the nonpersonal `_live_probe` dataset. A trusted operator can upsert that public revision and then delete it after the probe. The utility never prints keys, user records or authentication secrets. A real WebSocket subscription/delivery was verified during this implementation; SQL fixture tests roll back all identities/data.
