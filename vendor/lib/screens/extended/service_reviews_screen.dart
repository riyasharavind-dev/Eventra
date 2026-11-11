import 'package:eventor_vendor/services/app_settings_controller.dart';
import 'package:eventor_vendor/core/theme/app_icon_colors.dart';

import '../../services/app_live_data.dart';
import '../../widgets/vendor_page_scaffold.dart';
import '../../widgets/common/app_shimmer.dart';

import 'package:flutter/material.dart';

import '../../models/service_review_model.dart';
import '../../repositories/review_repository.dart';

class ServiceReviewsScreen extends StatefulWidget {
  final String? serviceId, businessId;
  final bool vendorMode;
  final ReviewRepository? repository;
  const ServiceReviewsScreen({
    super.key,
    this.serviceId,
    this.businessId,
    this.vendorMode = false,
    this.repository,
  }) : assert(serviceId != null || businessId != null || vendorMode);
  @override
  State<ServiceReviewsScreen> createState() => _ServiceReviewsScreenState();
}

class _ServiceReviewsScreenState extends State<ServiceReviewsScreen>
    with LiveDataState<ServiceReviewsScreen> {
  @override
  bool get liveCanRefresh => busyIds.isEmpty;
  @override
  Set<String> get liveDatasets => {
    'own:service_reviews',
    'own:service_review_reports',
    'own:bookings',
  };
  @override
  Future<void> onLiveData(Set<String> changed) async {
    await load();
  }

  late final ReviewRepository repo;
  final rows = <ServiceReviewModel>[];
  final busyIds = <String>{};
  ReviewSummary? summary;
  bool loading = true, loadingMore = false, hasMore = false;
  Object? error;
  int generation = 0;
  String t(String en) => AppSettingsScope.source(context, en);
  @override
  void initState() {
    super.initState();
    repo = widget.repository ?? ReviewRepository();
    load();
  }

  Future<void> load() async {
    final request = ++generation;
    setState(() {
      if (!liveRefreshing) loading = true;
      error = null;
      loadingMore = false;
    });
    try {
      final vendorId =
          widget.vendorMode &&
              widget.serviceId == null &&
              widget.businessId == null
          ? repo.db.auth.currentUser?.id
          : null;
      final total = await repo.summary(
        serviceId: widget.serviceId,
        businessId: widget.businessId,
        vendorId: vendorId,
      );
      final page = await repo.page(
        serviceId: widget.serviceId,
        businessId: widget.businessId,
        vendorMode: widget.vendorMode,
      );
      if (!mounted || request != generation) {
        return;
      }
      setState(() {
        summary = total;
        rows
          ..clear()
          ..addAll(page);
        hasMore = page.length == 20;
        loading = false;
      });
    } catch (e) {
      if (mounted && request == generation) {
        setState(() {
          error = e;
          loading = false;
        });
      }
    }
  }

  Future<void> more() async {
    if (loadingMore || loading || !hasMore || rows.isEmpty) {
      return;
    }
    final request = generation;
    setState(() => loadingMore = true);
    try {
      final page = await repo.page(
        serviceId: widget.serviceId,
        businessId: widget.businessId,
        vendorMode: widget.vendorMode,
        before: rows.last,
      );
      if (!mounted || request != generation) {
        return;
      }
      setState(() {
        final ids = rows.map((r) => r.id).toSet();
        rows.addAll(page.where((r) => ids.add(r.id)));
        hasMore = page.length == 20;
      });
    } catch (e) {
      if (mounted && request == generation) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted && request == generation) {
        setState(() => loadingMore = false);
      }
    }
  }

  Future<void> reportReview(ServiceReviewModel review) async {
    if (busyIds.contains(review.id)) {
      return;
    }
    setState(() => busyIds.add(review.id));
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (c) => const _ReviewTextDialog(),
      );
      if (result == null || !mounted) {
        return;
      }
      await repo.report(review, result);
      if (mounted) {
        await load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => busyIds.remove(review.id));
      }
    }
  }

  Widget summaryCard() {
    final value = summary!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0EDF0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF80152C).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value.count == 0
                    ? AppSettingsScope.translate(
                        context,
                        "vendor.no_reviews_yet.8b670b7e",
                      )
                    : value.average!.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF17171B),
                ),
              ),
              if (value.count > 0) ...[
                const SizedBox(width: 6),
                const Text(
                  '/ 5',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF73737D),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFFFCB48),
                  size: 24,
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${value.count} ${AppSettingsScope.translate(context, "vendor.public_reviews.56233001")}',
            style: const TextStyle(color: Color(0xFF73737D), fontSize: 13),
          ),
          if (value.count > 0) ...[
            const SizedBox(height: 14),
            ...List.generate(5, (i) {
              final star = 5 - i, count = value.stars[star] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Row(
                        children: [
                          Text(
                            '$star',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Color(0xFFFFCB48),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: count / value.count,
                          minHeight: 7,
                          backgroundColor: const Color(0xFFF4F2F4),
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF80152C),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 24,
                      child: Text(
                        '$count',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF73737D),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (widget.vendorMode) ...[
            const SizedBox(height: 14),
            Text(
              AppSettingsScope.translate(
                context,
                "vendor.only_visible_reviews_contribute_to_ratings_hi.8c7c91c9",
              ),
              style: const TextStyle(fontSize: 11, color: Color(0xFF73737D)),
            ),
          ],
        ],
      ),
    );
  }

  Widget reviewCard(ServiceReviewModel review) {
    final busy = busyIds.contains(review.id);
    final initial = review.customerName.trim().isNotEmpty
        ? review.customerName.trim()[0].toUpperCase()
        : 'U';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0EDF0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF80152C).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5E8EC),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFCB48),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFF80152C),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF17171B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Row(
                          children: List.generate(
                            5,
                            (starIndex) => Icon(
                              starIndex < review.rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 15,
                              color: const Color(0xFFFFCB48),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          MaterialLocalizations.of(context)
                              .formatMediumDate(review.createdAt.toLocal()),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF73737D),
                          ),
                        ),
                        if (review.version > 1) ...[
                          const SizedBox(width: 6),
                          Text(
                            '· ${AppSettingsScope.translate(context, "vendor.edited.7117f080")}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF73737D),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '✓ ${AppSettingsScope.translate(context, "vendor.verified_completed_booking.9c6d6a2c")}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E7D32),
              ),
            ),
          ),
          if (widget.serviceId == null) ...[
            const SizedBox(height: 8),
            Text(
              review.serviceName,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xFF17171B),
              ),
            ),
          ],
          if (review.moderationStatus == 'hidden')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                AppSettingsScope.translate(
                  context,
                  "vendor.hidden_by_admin.be64441e",
                ),
                style: const TextStyle(color: Color(0xFFC62828), fontSize: 12),
              ),
            ),
          if (review.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              review.text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Color(0xFF333339),
              ),
            ),
          ],
          if (review.vendorReply?.isNotEmpty == true) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8FA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF2D1DC)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.reply_rounded,
                        size: 16,
                        color: AppIconColors.standard,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        AppSettingsScope.translate(
                          context,
                          "vendor.vendor_response.6eac74fd",
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Color(0xFF80152C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    review.vendorReply!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFF202638),
                    ),
                  ),
                  if (review.repliedAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      MaterialLocalizations.of(context)
                          .formatMediumDate(review.repliedAt!.toLocal()),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF73737D),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (widget.vendorMode) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF73737D),
                  ),
                  onPressed: busy || review.reported
                      ? null
                      : () => reportReview(review),
                  icon: const Icon(Icons.flag_outlined, size: 16),
                  label: Text(
                    review.reported
                        ? AppSettingsScope.translate(
                            context,
                            "vendor.reported.34540bb7",
                          )
                        : AppSettingsScope.translate(
                            context,
                            "vendor.report.b6ce788d",
                          ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          if (busy) const ShimmerLoadingBar(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => VendorPageScaffold(
    backgroundColor: const Color(0xFFF8F8FA),
    appBar: AppBar(
      backgroundColor: const Color(0xFFF8F8FA),
      surfaceTintColor: Colors.transparent,
      title: Text(
        widget.vendorMode
            ? AppSettingsScope.translate(
                context,
                "vendor.customer_reviews.8f8b1729",
              )
            : AppSettingsScope.translate(context, "vendor.reviews.84cb7871"),
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
      ),
    ),
    body: AppShimmerRefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (loading)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(
                child: AppContentSkeleton(layout: SkeletonLayout.listings),
              ),
            ),
          if (error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      AppSettingsScope.translate(
                        context,
                        "vendor.unable_to_load_reviews.f1be9338",
                      ),
                    ),
                    TextButton(
                      onPressed: load,
                      child: Text(
                        AppSettingsScope.translate(
                          context,
                          "vendor.retry.942087cc",
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (summary != null) summaryCard(),
          const SizedBox(height: 12),
          ...rows.map(reviewCard),
          if (!loading && error == null && rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                AppSettingsScope.translate(
                  context,
                  "vendor.reviews_from_completed_bookings_will_appear_h.3963ba96",
                ),
              ),
            ),
          if (hasMore)
            OutlinedButton(
              onPressed: loadingMore || loading ? null : more,
              child: Text(
                loadingMore
                    ? AppSettingsScope.translate(
                        context,
                        "vendor.loading.ba3bbbe1",
                      )
                    : AppSettingsScope.translate(
                        context,
                        "vendor.load_more.ac8991ef",
                      ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _ReviewTextDialog extends StatefulWidget {
  const _ReviewTextDialog();
  @override
  State<_ReviewTextDialog> createState() => _ReviewTextDialogState();
}

class _ReviewTextDialogState extends State<_ReviewTextDialog> {
  final form = GlobalKey<FormState>();
  final text = TextEditingController();
  String t(String en) => AppSettingsScope.source(context, en);
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      AppSettingsScope.translate(context, "vendor.report_review.caa4bf2a"),
    ),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppSettingsScope.translate(
                context,
                "vendor.an_admin_will_review_your_report_reporting_do.069e7974",
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: text,
              maxLines: 5,
              maxLength: 1000,
              decoration: InputDecoration(
                labelText: AppSettingsScope.translate(
                  context,
                  "vendor.reason.f81ab834",
                ),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v?.trim().length ?? 0) < 3
                  ? AppSettingsScope.translate(
                      context,
                      "vendor.enter_at_least_3_characters.7638f7f1",
                    )
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(
          AppSettingsScope.translate(context, "vendor.cancel.19766ed6"),
        ),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, text.text.trim());
          }
        },
        child: Text(
          AppSettingsScope.translate(context, "vendor.report.b6ce788d"),
        ),
      ),
    ],
  );
}
