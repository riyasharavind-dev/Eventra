import 'package:eventor_vendor/services/app_settings_controller.dart';

import '../../widgets/vendor_page_scaffold.dart';
import '../../widgets/common/app_shimmer.dart';

import 'package:flutter/material.dart';

import '../../models/service_review_model.dart';
import '../../repositories/review_repository.dart';

class WriteReviewScreen extends StatefulWidget {
  final String bookingId;
  final ReviewRepository? repository;
  const WriteReviewScreen({
    super.key,
    required this.bookingId,
    this.repository,
  });
  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  late final ReviewRepository repo;
  final text = TextEditingController();
  BookingReviewContext? data;
  Object? error;
  bool loading = true, saving = false;
  int rating = 0;
  String t(String en) => AppSettingsScope.source(context, en);
  @override
  void initState() {
    super.initState();
    repo = widget.repository ?? ReviewRepository();
    load();
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final context = await repo.bookingContext(widget.bookingId);
      if (!mounted) {
        return;
      }
      setState(() {
        data = context;
        rating = context.review?.rating ?? 0;
        text.text = context.review?.text ?? '';
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          loading = false;
        });
      }
    }
  }

  Future<void> save() async {
    if (saving || data == null || !data!.canReview) {
      return;
    }
    if (rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppSettingsScope.translate(
              context,
              "vendor.choose_a_star_rating.6a7b59e9",
            ),
          ),
        ),
      );
      return;
    }
    if (text.text.length > 2000) {
      return;
    }
    setState(() => saving = true);
    try {
      await repo.submit(
        bookingId: widget.bookingId,
        rating: rating,
        text: text.text,
        expectedVersion: data!.review?.version ?? 0,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> reload() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          AppSettingsScope.translate(
            context,
            "vendor.reload_saved_review.217e6c8e",
          ),
        ),
        content: Text(
          AppSettingsScope.translate(
            context,
            "vendor.unsaved_changes_will_be_replaced.26ae3020",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(
              AppSettingsScope.translate(context, "vendor.cancel.19766ed6"),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(
              AppSettingsScope.translate(context, "vendor.reload.bdc090ec"),
            ),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !saving,
      child: VendorPageScaffold(
        backgroundColor: const Color(0xFFF8F8FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF8F8FA),
          surfaceTintColor: Colors.transparent,
          title: Text(
            data?.review == null
                ? AppSettingsScope.translate(
                    context,
                    "vendor.write_a_review.95627b89",
                  )
                : AppSettingsScope.translate(
                    context,
                    "vendor.edit_review.dc6ae842",
                  ),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ),
        body: loading
            ? const Center(
                child: AppContentSkeleton(layout: SkeletonLayout.form),
              )
            : error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppSettingsScope.translate(
                          context,
                          "vendor.unable_to_load_your_booking.d565667d",
                        ),
                      ),
                      TextButton(
                        onPressed: load,
                        child: Text(
                          AppSettingsScope.translate(
                            context,
                            "vendor.retry.942087cc",
                          ),
                          style: const TextStyle(
                            color: Color(0xFF80152C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : AbsorbPointer(
                absorbing: saving,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF0EDF0)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF80152C)
                                .withValues(alpha: 0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data!.serviceName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF17171B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (!data!.canReview)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                AppSettingsScope.translate(
                                  context,
                                  "vendor.only_the_customer_of_a_completed_booking_can_.7dbb0611",
                                ),
                                style: const TextStyle(
                                  color: Color(0xFFE65100),
                                ),
                              ),
                            )
                          else ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '✓ ${AppSettingsScope.translate(context, "vendor.verified_completed_booking.9c6d6a2c")}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                            if (data!.review?.moderationStatus == 'hidden')
                              Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Text(
                                  AppSettingsScope.translate(
                                    context,
                                    "vendor.this_review_is_hidden_by_moderation_editing_d.8ed8441d",
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFFC62828),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 24),
                            Text(
                              AppSettingsScope.translate(
                                context,
                                "vendor.how_was_the_service.04742df9",
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF17171B),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: List.generate(
                                5,
                                (i) => IconButton(
                                  tooltip: '${i + 1} / 5',
                                  padding: const EdgeInsets.only(right: 6),
                                  constraints: const BoxConstraints(),
                                  onPressed: () =>
                                      setState(() => rating = i + 1),
                                  icon: Icon(
                                    i < rating
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    color: const Color(0xFFFFCB48),
                                    size: 38,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              rating > 0
                                  ? '$rating / 5 ★'
                                  : AppSettingsScope.translate(
                                      context,
                                      "vendor.tap_a_star_to_rate.1f083de3",
                                    ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: Color(0xFF73737D),
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: text,
                              maxLines: 5,
                              maxLength: 2000,
                              decoration: InputDecoration(
                                labelText: AppSettingsScope.translate(
                                  context,
                                  "vendor.your_experience_optional.358d4c63",
                                ),
                                filled: true,
                                fillColor: const Color(0xFFFBF9FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE8E5E8),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE8E5E8),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF80152C),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              AppSettingsScope.translate(
                                context,
                                "vendor.your_name_rating_and_review_will_be_public_av.f260b089",
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: Color(0xFF73737D),
                              ),
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF80152C),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 2,
                                  shadowColor: const Color(0xFF80152C)
                                      .withValues(alpha: 0.3),
                                ),
                                onPressed: save,
                                child: Text(
                                  saving
                                      ? AppSettingsScope.translate(
                                          context,
                                          "vendor.saving.23e39291",
                                        )
                                      : AppSettingsScope.translate(
                                          context,
                                          "vendor.save_review.e5a490bf",
                                        ),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: TextButton(
                                onPressed: reload,
                                child: Text(
                                  AppSettingsScope.translate(
                                    context,
                                    "vendor.reload_saved_review.1cfe2eeb",
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFF73737D),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
