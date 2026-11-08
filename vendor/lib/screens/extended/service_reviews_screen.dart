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
  String t(String en, String ta) =>
      Localizations.localeOf(context).languageCode == 'ta' ? ta : en;
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

  Future<void> action(ServiceReviewModel review, {bool report = false}) async {
    if (busyIds.contains(review.id)) {
      return;
    }
    setState(() => busyIds.add(review.id));
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (c) => _ReviewTextDialog(
          report: report,
          initial: report ? '' : review.vendorReply ?? '',
        ),
      );
      if (result == null || !mounted) {
        return;
      }
      if (report) {
        await repo.report(review, result);
      } else {
        await repo.reply(review, result);
      }
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
                    ? t('No reviews yet', 'இன்னும் விமர்சனங்கள் இல்லை')
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
            '${value.count} ${t('public reviews', 'பொது விமர்சனங்கள்')}',
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
              t(
                'Only visible reviews contribute to ratings. Hidden reviews are labelled below.',
                'தெரியும் விமர்சனங்கள் மட்டுமே மதிப்பீட்டில் சேரும். மறைக்கப்பட்டவை கீழே குறிப்பிடப்பட்டுள்ளன.',
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
                            '· ${t('Edited', 'திருத்தப்பட்டது')}',
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
              '✓ ${t('Verified completed booking', 'சரிபார்க்கப்பட்ட முடிந்த முன்பதிவு')}',
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
                t('Hidden by admin', 'நிர்வாகத்தால் மறைக்கப்பட்டது'),
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
                        t('Vendor response', 'விற்பனையாளர் பதில்'),
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
          if (widget.vendorMode && review.canReply) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF80152C),
                    side: const BorderSide(color: Color(0xFF80152C)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: busy ? null : () => action(review),
                  icon: const Icon(Icons.reply_outlined, size: 16),
                  label: Text(
                    review.vendorReply == null
                        ? t('Reply', 'பதில் அளி')
                        : t('Edit reply', 'பதிலைத் திருத்து'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF73737D),
                  ),
                  onPressed: busy || review.reported
                      ? null
                      : () => action(review, report: true),
                  icon: const Icon(Icons.flag_outlined, size: 16),
                  label: Text(
                    review.reported
                        ? t('Reported', 'புகாரளிக்கப்பட்டது')
                        : t('Report', 'புகார் அளி'),
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
            ? t('Customer Reviews', 'வாடிக்கையாளர் விமர்சனங்கள்')
            : t('Reviews', 'விமர்சனங்கள்'),
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
                      t(
                        'Unable to load reviews.',
                        'விமர்சனங்களை ஏற்ற முடியவில்லை.',
                      ),
                    ),
                    TextButton(
                      onPressed: load,
                      child: Text(t('Retry', 'மீண்டும் முயற்சி')),
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
                t(
                  'Reviews from completed bookings will appear here.',
                  'முடிந்த முன்பதிவுகளின் விமர்சனங்கள் இங்கே தோன்றும்.',
                ),
              ),
            ),
          if (hasMore)
            OutlinedButton(
              onPressed: loadingMore || loading ? null : more,
              child: Text(
                loadingMore
                    ? t('Loading…', 'ஏற்றுகிறது…')
                    : t('Load more', 'மேலும் ஏற்று'),
              ),
            ),
        ],
      ),
    ),
  );
}

class _ReviewTextDialog extends StatefulWidget {
  final bool report;
  final String initial;
  const _ReviewTextDialog({required this.report, required this.initial});
  @override
  State<_ReviewTextDialog> createState() => _ReviewTextDialogState();
}

class _ReviewTextDialogState extends State<_ReviewTextDialog> {
  final form = GlobalKey<FormState>();
  late final TextEditingController text;
  String t(String en, String ta) =>
      Localizations.localeOf(context).languageCode == 'ta' ? ta : en;
  @override
  void initState() {
    super.initState();
    text = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.report
          ? t('Report review', 'விமர்சனத்தைப் புகாரளி')
          : t('Vendor reply', 'விற்பனையாளர் பதில்'),
    ),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.report
                  ? t(
                      'An admin will review your report. Reporting does not automatically hide this review.',
                      'உங்கள் புகாரை நிர்வாகி பரிசீலிப்பார். புகாரளிப்பதால் விமர்சனம் தானாக மறைக்கப்படாது.',
                    )
                  : t(
                      'Your reply is public. Clear the text to remove an existing reply.',
                      'உங்கள் பதில் பொதுவாகத் தெரியும். முந்தைய பதிலை நீக்க உரையை அழிக்கவும்.',
                    ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: text,
              maxLines: 5,
              maxLength: widget.report ? 1000 : 2000,
              decoration: InputDecoration(
                labelText: widget.report
                    ? t('Reason', 'காரணம்')
                    : t('Reply', 'பதில்'),
                border: const OutlineInputBorder(),
              ),
              validator: (v) => widget.report && (v?.trim().length ?? 0) < 3
                  ? t(
                      'Enter at least 3 characters',
                      'குறைந்தது 3 எழுத்துகள் உள்ளிடவும்',
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
        child: Text(t('Cancel', 'ரத்து செய்')),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, text.text.trim());
          }
        },
        child: Text(t('Submit', 'சமர்ப்பி')),
      ),
    ],
  );
}
