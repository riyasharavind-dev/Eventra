# Explore categories and global search trends

All displays only parent category cards. The side rail contains the same roots in the same ranked order. Selecting a root displays every descendant type in one flat grid; there is no breadcrumb/drill-down chain and no inline service feed. Selecting a subtype explicitly opens the shared screens/extended/result_screen.dart with paginated services for that entire subtree.

Explore loads category metadata and aggregate rankings only. It no longer downloads the complete active-service catalog. The shared result page uses customer_category_results with category/subtree scope, result-type filters, global sorting and 20-item pages. Text search uses the same UI with its normal search scope.

Explicit submitted searches, including recent-search taps, record customer category interest through customer_record_category_search. Debounced typing, pagination, result filters and retries do not add votes. Each customer has one bounded signal per category, with repeat updates throttled for ten minutes. Matching subtypes promote their ancestors. Global ranking uses the last 30 days, weighted twice for the last seven days. With no trend signals, existing category order is the stable fallback. Tracking starts with this implementation; personal device history is not uploaded.

Signals stay in the private eventra_feed schema with RLS, no client table access and no stored search phrases. Only category/aggregate score pairs are public. Vendor/anonymous clients cannot write customer signals. Storage is capped at 200 category signals per customer with 180-day cleanup on their next write. Category deletion and customer deletion cascade. Public category_trends revision hints are throttled to five minutes; returning from Search refreshes rankings immediately.

Schema/RPCs: admin/sql/34_explore_category_trends.sql. Regression tests: admin/sql/tests/explore_trends_test.sql (rollback fixtures), plus Explore hierarchy/order and submitted-search tests in customer/test.
