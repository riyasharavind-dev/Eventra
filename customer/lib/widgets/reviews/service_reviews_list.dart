import 'package:eventor_customer/services/app_settings_controller.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/service_review_model.dart';
import '../../repositories/review_repository.dart';
import '../../services/app_live_data.dart';
import 'service_review_card.dart';
import 'review_rating_summary.dart';

Future<void> showServiceRatingReviews(
  BuildContext context, {
  required String serviceId,
  required int rating,
  ReviewRepository? repository,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (context) => FractionallySizedBox(
    heightFactor: .88,
    child: SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    AppSettingsScope.translate(
                      context,
                      "customer.value0_star_reviews.b57bdc32",
                      args: {"value0": rating},
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF17171B),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: AppSettingsScope.translate(
                    context,
                    "customer.close_reviews.237f84c4",
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF73737D)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0EDF0)),
          Expanded(
            child: ServiceReviewsList(
              serviceId: serviceId,
              rating: rating,
              repository: repository,
            ),
          ),
        ],
      ),
    ),
  ),
);

/// Paginated public reviews reused by the overall screen and star-filter popup.
class ServiceReviewsList extends StatefulWidget {
  const ServiceReviewsList({
    super.key,
    required this.serviceId,
    this.rating,
    this.repository,
  });
  final String serviceId;
  final int? rating;
  final ReviewRepository? repository;
  @override
  State<ServiceReviewsList> createState() => _ReviewsListState();
}

class _ReviewsListState extends State<ServiceReviewsList>
    with LiveDataState<ServiceReviewsList> {
  late final repo = widget.repository ?? ReviewRepository();
  List<ServiceReviewModel> rows = [];
  ReviewSummary summary = const ReviewSummary(count: 0);
  bool loading = true, failed = false, more = false;
  int generation = 0;
  Timer? renewal;
  @override
  Set<String> get liveDatasets => {
    'public:service_reviews',
    'public:service_metrics',
    'own:service_reviews',
  };
  @override
  Future<void> onLiveData(Set<String> changed) => load(quiet: true);
  @override
  void initState() {
    super.initState();
    load();
    renewal = Timer.periodic(const Duration(minutes: 4), (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true && !loading) {
        load(quiet: true);
      }
    });
  }

  @override
  void dispose() {
    renewal?.cancel();
    super.dispose();
  }

  Future<void> load({bool append = false, bool quiet = false}) async {
    if (append && loading) return;
    final request = append ? generation : ++generation;
    final keep = quiet ? rows.length : 0;
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final result = await Future.wait<dynamic>([
        repo.page(
          serviceId: widget.serviceId,
          rating: widget.rating,
          before: append && rows.isNotEmpty ? rows.last : null,
          limit: 20,
        ),
        append
            ? Future.value(summary)
            : repo.summary(serviceId: widget.serviceId),
      ]);
      final page = List<ServiceReviewModel>.from(result[0] as List);
      var lastSize = page.length;
      while (!append && page.length < keep && lastSize == 20) {
        if (!mounted || request != generation) return;
        final extra = await repo.page(
          serviceId: widget.serviceId,
          rating: widget.rating,
          before: page.last,
          limit: 20,
        );
        lastSize = extra.length;
        page.addAll(extra);
      }
      if (!mounted || request != generation) return;
      setState(() {
        rows = append
            ? {
                for (final r in [...rows, ...page]) r.id: r,
              }.values.toList()
            : page;
        summary = result[1] as ReviewSummary;
        more = lastSize == 20;
        loading = false;
      });
    } catch (_) {
      if (mounted && request == generation) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () => load(),
    child: NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.axis == Axis.vertical &&
            n.metrics.extentAfter < 250 &&
            more &&
            !loading &&
            !failed) {
          load(append: true);
        }
        return false;
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (widget.rating == null) ...[
            ReviewRatingSummary(
              summary: summary,
              onRatingSelected: (rating) => showServiceRatingReviews(
                context,
                serviceId: widget.serviceId,
                rating: rating,
                repository: repo,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (widget.rating != null && !loading)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                AppSettingsScope.translate(
                  context,
                  "customer.value0_public_reviews.79122f99",
                  args: {"value0": summary.stars[widget.rating] ?? 0},
                ),
                style: const TextStyle(color: Color(0xFF73737D), fontSize: 12),
              ),
            ),
          if (loading && rows.isEmpty)
            const LinearProgressIndicator(color: Color(0xFF80152C)),
          if (!loading && !failed && rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  widget.rating == null
                      ? 'No reviews yet.'
                      : 'No ${widget.rating}-star reviews yet.',
                ),
              ),
            ),
          for (final review in rows)
            ServiceReviewCard(
              key: ValueKey(review.id),
              review: review,
              onRatingTap: widget.rating == null
                  ? () => showServiceRatingReviews(
                      context,
                      serviceId: widget.serviceId,
                      rating: review.rating,
                      repository: repo,
                    )
                  : null,
            ),
          if (failed)
            TextButton(
              onPressed: () => load(append: rows.isNotEmpty),
              child: Text(
                AppSettingsScope.translate(
                  context,
                  "customer.unable_to_load_reviews_retry.24e22b40",
                ),
              ),
            ),
          if (more && !failed)
            Center(
              child: TextButton(
                onPressed: loading ? null : () => load(append: true),
                child: Text(loading ? 'Loading…' : 'More reviews'),
              ),
            ),
        ],
      ),
    ),
  );
}
