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

class _ReviewRatingCardState extends State<ReviewRatingCard> {
  late ReviewRepository repo;
  late Future<ReviewSummary> loading;
  bool opening = false;
  String t(String en, String ta) =>
      Localizations.localeOf(context).languageCode == 'ta' ? ta : en;
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
            : t('No reviews yet', 'இன்னும் விமர்சனங்கள் இல்லை');
        final title = widget.vendorId != null
            ? t('Vendor rating', 'விற்பனையாளர் மதிப்பீடு')
            : widget.businessId != null
            ? t('Business rating', 'வணிக மதிப்பீடு')
            : t('Service rating', 'சேவை மதிப்பீடு');
        final message = failed
            ? t(
                'Rating unavailable · tap to retry',
                'மதிப்பீடு கிடைக்கவில்லை · மீண்டும் முயற்சி',
              )
            : waiting
            ? t('Loading rating…', 'மதிப்பீடு ஏற்றுகிறது…')
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
                    Icon(Icons.star_rounded, size: 19, color: colors.primary),
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
                        '· ${data.count} ${t('reviews', 'விமர்சனங்கள்')}',
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
                        Icon(
                          Icons.star_rounded,
                          color: colors.primary,
                          size: 28,
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
                                  '${data.count} ${t('public reviews', 'பொது விமர்சனங்கள்')}',
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
                            ? t(
                                'Based on visible customer reviews across all your businesses and services.',
                                'உங்கள் அனைத்து வணிகங்கள் மற்றும் சேவைகளின் தெரியும் வாடிக்கையாளர் விமர்சனங்களின் அடிப்படையில்.',
                              )
                            : t(
                                'Based on visible customer reviews for this business or service.',
                                'இந்த வணிகம் அல்லது சேவையின் தெரியும் வாடிக்கையாளர் விமர்சனங்களின் அடிப்படையில்.',
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
          child: Material(
            color: widget.compact ? colors.surfaceContainerLow : colors.surface,
            borderRadius: BorderRadius.circular(widget.compact ? 10 : 18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(onTap: tap, child: body),
          ),
        );
      },
    );
  }
}
