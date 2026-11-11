import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:flutter/material.dart';

import '../../models/service_review_model.dart';
import '../../repositories/review_repository.dart';
import '../../services/app_live_data.dart';
import '../../screens/extended/service_reviews_screen.dart';
import 'review_rating_summary.dart';
import 'service_reviews_list.dart';

/// Lightweight service-page summary; full reviews open in their own screen.
class ServiceReviewsSection extends StatefulWidget {
  const ServiceReviewsSection({
    super.key,
    required this.serviceId,
    this.repository,
  });
  final String serviceId;
  final ReviewRepository? repository;
  @override
  State<ServiceReviewsSection> createState() => _ReviewSummaryState();
}

class _ReviewSummaryState extends State<ServiceReviewsSection>
    with LiveDataState<ServiceReviewsSection> {
  late final repo = widget.repository ?? ReviewRepository();
  ReviewSummary summary = const ReviewSummary(count: 0);
  bool loading = true, failed = false;
  int generation = 0;
  @override
  Set<String> get liveDatasets => {
    'public:service_reviews',
    'public:service_metrics',
    'own:service_reviews',
  };
  @override
  Future<void> onLiveData(Set<String> changed) => load();
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final request = ++generation;
    try {
      final data = await repo.summary(serviceId: widget.serviceId);
      if (mounted && request == generation) {
        setState(() {
          summary = data;
          loading = false;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted && request == generation) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  Future<void> allReviews() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            ServiceReviewsScreen(serviceId: widget.serviceId, repository: repo),
      ),
    );
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppSettingsScope.translate(
            context,
            "customer.customer_reviews.8f8b1729",
          ),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        ReviewRatingSummary(
          summary: summary,
          onRatingSelected: (rating) => showServiceRatingReviews(
            context,
            serviceId: widget.serviceId,
            rating: rating,
            repository: repo,
          ),
        ),
        if (loading) const LinearProgressIndicator(color: Color(0xFF80152C)),
        if (failed)
          TextButton(
            onPressed: load,
            child: Text(
              AppSettingsScope.translate(
                context,
                "customer.unable_to_load_reviews_retry.24e22b40",
              ),
            ),
          ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF80152C),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          onPressed: allReviews,
          child: Text(
            AppSettingsScope.translate(
              context,
              "customer.view_all_reviews_value0.740f7299",
              args: {"value0": summary.count},
            ),
          ),
        ),
      ],
    ),
  );
}
