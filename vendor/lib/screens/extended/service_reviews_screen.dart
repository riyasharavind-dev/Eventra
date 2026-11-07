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

class _ServiceReviewsScreenState extends State<ServiceReviewsScreen> {
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
      loading = true;
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
    final value = summary!, colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value.count == 0
                  ? t('No reviews yet', 'இன்னும் விமர்சனங்கள் இல்லை')
                  : '${value.average!.toStringAsFixed(1)} / 5',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              '${value.count} ${t('public reviews', 'பொது விமர்சனங்கள்')}',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            if (value.count > 0)
              ...List.generate(5, (i) {
                final star = 5 - i, count = value.stars[star] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Row(
                    children: [
                      Text('$star ★'),
                      const SizedBox(width: 10),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: count / value.count,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('$count'),
                    ],
                  ),
                );
              }),
            if (widget.vendorMode) ...[
              const SizedBox(height: 12),
              Text(
                t(
                  'Only visible reviews contribute to ratings. Hidden reviews are labelled below.',
                  'தெரியும் விமர்சனங்கள் மட்டுமே மதிப்பீட்டில் சேரும். மறைக்கப்பட்டவை கீழே குறிப்பிடப்பட்டுள்ளன.',
                ),
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget reviewCard(ServiceReviewModel review) {
    final colors = Theme.of(context).colorScheme,
        busy = busyIds.contains(review.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              review.customerName,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  '${review.rating} / 5 ★',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
                Text(
                  MaterialLocalizations.of(context)
                      .formatMediumDate(review.createdAt.toLocal()),
                ),
                if (review.version > 1) Text(t('Edited', 'திருத்தப்பட்டது')),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              t(
                'Verified completed booking',
                'சரிபார்க்கப்பட்ட முடிந்த முன்பதிவு',
              ),
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            ),
            if (widget.serviceId == null) ...[
              const SizedBox(height: 8),
              Text(
                review.serviceName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            if (review.moderationStatus == 'hidden')
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  t('Hidden by admin', 'நிர்வாகத்தால் மறைக்கப்பட்டது'),
                  style: TextStyle(color: colors.error),
                ),
              ),
            if (review.text.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(review.text),
            ],
            if (review.vendorReply?.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('Vendor response', 'விற்பனையாளர் பதில்'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(review.vendorReply!),
                    if (review.repliedAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        MaterialLocalizations.of(context)
                            .formatMediumDate(review.repliedAt!.toLocal()),
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (widget.vendorMode && review.canReply) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: busy ? null : () => action(review),
                    icon: const Icon(Icons.reply_outlined),
                    label: Text(
                      review.vendorReply == null
                          ? t('Reply', 'பதில் அளி')
                          : t('Edit reply', 'பதிலைத் திருத்து'),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: busy || review.reported
                        ? null
                        : () => action(review, report: true),
                    icon: const Icon(Icons.flag_outlined),
                    label: Text(
                      review.reported
                          ? t('Reported', 'புகாரளிக்கப்பட்டது')
                          : t('Report', 'புகார் அளி'),
                    ),
                  ),
                ],
              ),
            ],
            if (busy) const ShimmerLoadingBar(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => VendorPageScaffold(
    appBar: AppBar(
      title: Text(
        widget.vendorMode
            ? t('Customer Reviews', 'வாடிக்கையாளர் விமர்சனங்கள்')
            : t('Reviews', 'விமர்சனங்கள்'),
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
