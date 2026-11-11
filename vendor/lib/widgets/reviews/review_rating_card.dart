import 'package:eventor_vendor/services/app_settings_controller.dart';

import '../../services/app_live_data.dart';
import '../common/app_shimmer.dart';

import 'package:flutter/material.dart';

import '../../models/service_review_model.dart';
import '../../repositories/review_repository.dart';
import '../../screens/extended/service_reviews_screen.dart';

/// A live rating/count for one scope. The server averages visible individual
/// reviews, so business/vendor ratings are weighted by actual review counts.
class ReviewRatingCard extends StatefulWidget {
  final String? vendorId, businessId, serviceId;
  final bool compact, vendorMode;
  final Object? refreshKey;
  final ReviewRepository? repository;
  const ReviewRatingCard({
    super.key,
    this.vendorId,
    this.businessId,
    this.serviceId,
    this.compact = false,
    this.vendorMode = false,
    this.refreshKey,
    this.repository,
  }) : assert(
         (vendorId != null ? 1 : 0) +
                 (businessId != null ? 1 : 0) +
                 (serviceId != null ? 1 : 0) ==
             1,
       );
  @override
  State<ReviewRatingCard> createState() => _ReviewRatingCardState();
}

class _ReviewRatingCardState extends State<ReviewRatingCard>
    with LiveDataState<ReviewRatingCard> {
  @override
  Set<String> get liveDatasets => {
    'own:service_reviews',
    'own:service_metrics',
    'public:service_reviews',
  };
  @override
  Future<void> onLiveData(Set<String> changed) async {
    refresh();
    await loading;
  }

  late ReviewRepository repo;
  late Future<ReviewSummary> loading;
  bool opening = false;
  String t(String en) => AppSettingsScope.source(context, en);
  Future<ReviewSummary> fetch() => repo.summary(
    serviceId: widget.serviceId,
    businessId: widget.businessId,
    vendorId: widget.vendorId,
  );
  @override
  void initState() {
    super.initState();
    repo = widget.repository ?? ReviewRepository();
    loading = fetch();
  }

  @override
  void didUpdateWidget(covariant ReviewRatingCard old) {
    super.didUpdateWidget(old);
    if (old.repository != widget.repository) {
      repo = widget.repository ?? ReviewRepository();
    }
    if (old.vendorId != widget.vendorId ||
        old.businessId != widget.businessId ||
        old.serviceId != widget.serviceId ||
        old.refreshKey != widget.refreshKey ||
        old.repository != widget.repository) {
      loading = fetch();
    }
  }

  void refresh() {
    setState(() {
      loading = fetch();
    });
  }

  Future<void> open() async {
    if (opening) {
      return;
    }
    if (widget.vendorId != null && !widget.vendorMode) {
      return;
    }
    setState(() => opening = true);
    try {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ServiceReviewsScreen(
            serviceId: widget.serviceId,
            businessId: widget.businessId,
            vendorMode: widget.vendorMode,
            repository: repo,
          ),
        ),
      );
      if (mounted) {
        refresh();
      }
    } finally {
      if (mounted) {
        setState(() => opening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FutureBuilder<ReviewSummary>(
      future: loading,
      builder: (context, snapshot) {
        final failed = snapshot.hasError;
        final waiting = snapshot.connectionState != ConnectionState.done;
        final data = snapshot.data;
        final hasRating =
            data != null && data.count > 0 && data.average != null;
        final score = hasRating
            ? '${data.average!.toStringAsFixed(1)} / 5'
            : AppSettingsScope.translate(
                context,
                "vendor.no_reviews_yet.8b670b7e",
              );
        final title = widget.vendorId != null
            ? AppSettingsScope.translate(
                context,
                "vendor.vendor_rating.d0d46386",
              )
            : widget.businessId != null
            ? AppSettingsScope.translate(
                context,
                "vendor.business_rating.fd9c780b",
              )
            : AppSettingsScope.translate(
                context,
                "vendor.service_rating.bfe26f63",
              );
        final message = failed
            ? AppSettingsScope.translate(
                context,
                "vendor.rating_unavailable_tap_to_retry.8ac9a956",
              )
            : waiting
            ? AppSettingsScope.translate(
                context,
                "vendor.loading_rating.d198722a",
              )
            : score;
        final canOpen = widget.vendorId == null || widget.vendorMode;
        final VoidCallback? tap = waiting || opening
            ? null
            : failed
            ? refresh
            : canOpen
            ? open
            : null;
        final body = widget.compact
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Wrap(
                  spacing: 7,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 20,
                      color: const Color(0xFFFFCB48),
                    ),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    if (!failed && !waiting && hasRating)
                      Text(
                        '· ${data.count} ${AppSettingsScope.translate(context, "vendor.reviews.54641051")}',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    if (opening)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: AppShimmerIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFCB48),
                          size: 32,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              if (!failed && !waiting && data != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${data.count} ${AppSettingsScope.translate(context, "vendor.public_reviews.56233001")}',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (tap != null) const Icon(Icons.chevron_right),
                      ],
                    ),
                    if (!waiting && !failed) ...[
                      const SizedBox(height: 12),
                      Text(
                        widget.vendorId != null
                            ? AppSettingsScope.translate(
                                context,
                                "vendor.based_on_visible_customer_reviews_across_all_.2b368c8c",
                              )
                            : AppSettingsScope.translate(
                                context,
                                "vendor.based_on_visible_customer_reviews_for_this_bu.75a1e071",
                              ),
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.5,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              );
        return Semantics(
          label: title,
          button: tap != null,
          child: Container(
            decoration: BoxDecoration(
              color: widget.compact ? const Color(0xFFF5E8EC) : Colors.white,
              borderRadius: BorderRadius.circular(widget.compact ? 12 : 20),
              border: Border.all(
                color: widget.compact
                    ? const Color(0xFFF2D1DC)
                    : const Color(0xFFF0EDF0),
              ),
              boxShadow: widget.compact
                  ? null
                  : [
                      BoxShadow(
                        color: const Color(0xFF80152C).withValues(alpha: 0.05),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: Colors.transparent,
              child: InkWell(onTap: tap, child: body),
            ),
          ),
        );
      },
    );
  }
}
