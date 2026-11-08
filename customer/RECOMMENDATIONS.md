# Customer service recommendations

Applied database migration: `admin/sql/23_customer_recommendations.sql`.
Rollback-only database checks: `admin/sql/tests/recommendations_test.sql`.

## Connected screens

- Home adds a Recommended for you shelf before the existing administrator-controlled sections. Admin sections, their rules, pins, scheduling and pagination are unchanged.
- Service details adds a Related services shelf below existing information and above the fixed booking action bar. The opened service is always excluded. Matching alternatives appear before general discovery fallback.
- The reusable shelf uses existing cards, lazy horizontal rendering, pricing-type labels, loading/error states and bounded load-more pagination. Recommendation failure never blocks service details, local favorites or booking.
- Successful view/favorite changes debounce a home refresh; successful bookings also refresh it. Pull-to-refresh reloads both the personalized shelf and editorial feed.

## Ranking and balance

Related ranking uses category ancestors/siblings, event type, and price similarity only when pricing type AND unit match. Rating quality is smoothed with a five-review prior, alongside completed bookings and freshness. Repeated results from one vendor receive a ranking penalty; this is a soft diversity preference, not a guarantee that every row has different vendors.

Home learns from recent service views, saves and the signed-in customer's pending/accepted/completed bookings. Saves carry more weight than views, completed bookings more than pending requests. Signals decay with age. Canceled/rejected requests do not create positive interest. Three interest positions are interleaved with one non-interest discovery position when both pools contain enough services. Customers without history and guests get quality/freshness discovery. No paid placement is silently included in the ranking.

## Security and limits

- RPCs derive identity from auth.uid(), enforce customer account status, and reuse the existing eligible-services view. Inactive services/businesses, archived businesses and suspended/deleted vendors are filtered live.
- Signal rows are in the private eventra_feed schema, RLS enabled, with no customer/guest direct access. There is no public history-reading RPC.
- At most one row per customer/service. Views write at most once per ten minutes. New tracking activity prunes rows older than 180 days and caps the account at 200 rows. This is activity-driven pruning, not a scheduled global expiry job. Removing an account/service cascades the associated rows.
- Favorites remain locally persisted; best-effort signals are supplementary. Previously saved offline favorites are not backfilled automatically. Offline activity is not queued across sessions.
- Indexed candidate retrieval combines up to 400 recent, 200 popular, 400 related and 400 interest candidates before deduplication. Ranking processes this bounded union; it does not download the whole catalog to the device. Pages contain at most 20 items with offsets bounded to 200; the app requests 12.
- Pagination ordering uses stable ID tie breakers, and the controller deduplicates results and ignores stale/disposed requests. Results may move as live eligibility/history changes; refresh starts a new ranking.

## Scaling further

This is an explainable rules-based recommendation foundation, not a trained collaborative filtering model. Current-catalog checks do not establish performance at millions of services. Benchmark realistic catalog size/concurrency before growing traffic; candidate retrieval still queries live relational joins. At larger volume, precompute candidate pools/affinities, introduce versioned ranking snapshots/cursors and scheduled retention, and measure impressions, booking conversion and diversity before changing weights. Keep the RPC payload stable so those server-side changes do not require rebuilding screen widgets.
