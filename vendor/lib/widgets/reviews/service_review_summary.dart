import 'package:eventor_vendor/services/app_settings_controller.dart';
import 'package:eventor_vendor/core/theme/app_icon_colors.dart';

import '../../services/app_live_data.dart';
import '../common/app_shimmer.dart';

import 'package:flutter/material.dart';

import '../../models/service_review_model.dart';
import '../../repositories/review_repository.dart';
import '../../screens/extended/service_reviews_screen.dart';

class ServiceReviewSummary extends StatefulWidget {
  final String serviceId;
  final bool vendorMode;
  final ReviewRepository? repository;
  const ServiceReviewSummary({
    super.key,
    required this.serviceId,
    this.vendorMode = false,
    this.repository,
  });
  @override
  State<ServiceReviewSummary> createState() => _ServiceReviewSummaryState();
}

class _ServiceReviewSummaryState extends State<ServiceReviewSummary>
    with LiveDataState<ServiceReviewSummary> {
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

  late final ReviewRepository repo;
  late Future<ReviewSummary> loading;
  @override
  void initState() {
    super.initState();
    repo = widget.repository ?? ReviewRepository();
    loading = repo.summary(serviceId: widget.serviceId);
  }

  @override
  void didUpdateWidget(covariant ServiceReviewSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serviceId != widget.serviceId) {
      loading = repo.summary(serviceId: widget.serviceId);
    }
  }

  void refresh() {
    setState(() {
      loading = repo.summary(serviceId: widget.serviceId);
    });
  }

  Future<void> open() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ServiceReviewsScreen(
          serviceId: widget.serviceId,
          vendorMode: widget.vendorMode,
          repository: repo,
        ),
      ),
    );
    if (mounted) {
      refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ReviewSummary>(
      future: loading,
      builder: (context, snapshot) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF0EDF0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF80152C).withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF5E8EC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.star_rounded,
                color: Color(0xFFFFCB48),
                size: 24,
              ),
            ),
            title: Text(
              AppSettingsScope.translate(
                context,
                "vendor.ratings_reviews.040a641f",
              ),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: Text(
              snapshot.hasError
                  ? (AppSettingsScope.translate(
                      context,
                      "vendor.unable_to_load_tap_to_retry.356321f4",
                    ))
                  : !snapshot.hasData
                  ? (AppSettingsScope.translate(
                      context,
                      "vendor.loading.ba3bbbe1",
                    ))
                  : snapshot.data!.count == 0
                  ? (AppSettingsScope.translate(
                      context,
                      "vendor.no_reviews_yet.8b670b7e",
                    ))
                  : '${snapshot.data!.average!.toStringAsFixed(1)} / 5 · ${snapshot.data!.count} ${AppSettingsScope.translate(context, "vendor.reviews.54641051")}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF73737D)),
            ),
            trailing: snapshot.connectionState == ConnectionState.waiting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: AppShimmerIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF80152C),
                    ),
                  )
                : const Icon(
                    Icons.chevron_right,
                    color: AppIconColors.standard,
                  ),
            onTap: snapshot.hasError ? refresh : open,
          ),
        ),
      ),
    );
  }
}
