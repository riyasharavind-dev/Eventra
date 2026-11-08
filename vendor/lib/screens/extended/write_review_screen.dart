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
  String t(String en, String ta) =>
      Localizations.localeOf(context).languageCode == 'ta' ? ta : en;
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
            t(
              'Choose a star rating.',
              'நட்சத்திர மதிப்பீட்டைத் தேர்வு செய்யவும்.',
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
          t('Reload saved review?', 'சேமித்த விமர்சனத்தை மீண்டும் ஏற்றவா?'),
        ),
        content: Text(
          t(
            'Unsaved changes will be replaced.',
            'சேமிக்காத மாற்றங்கள் மாற்றப்படும்.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(t('Cancel', 'ரத்து செய்')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(t('Reload', 'மீண்டும் ஏற்று')),
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
                ? t('Write a Review', 'விமர்சனம் எழுது')
                : t('Edit Review', 'விமர்சனத்தைத் திருத்து'),
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
                        t(
                          'Unable to load your booking.',
                          'உங்கள் முன்பதிவை ஏற்ற முடியவில்லை.',
                        ),
                      ),
                      TextButton(
                        onPressed: load,
                        child: Text(
                          t('Retry', 'மீண்டும் முயற்சி'),
                          style: const TextStyle(color: Color(0xFF80152C), fontWeight: FontWeight.w700),
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
                            color: const Color(0xFF80152C).withValues(alpha: 0.05),
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
                                t(
                                  'Only the customer of a completed booking can review this service.',
                                  'முடிந்த முன்பதிவின் வாடிக்கையாளர் மட்டுமே இந்த சேவையை மதிப்பிட முடியும்.',
                                ),
                                style: const TextStyle(color: Color(0xFFE65100)),
                              ),
                            )
                          else ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '✓ ${t('Verified completed booking', 'சரிபார்க்கப்பட்ட முடிந்த முன்பதிவு')}',
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
                                  t(
                                    'This review is hidden by moderation. Editing does not publish it again.',
                                    'இந்த விமர்சனம் நிர்வாகத்தால் மறைக்கப்பட்டுள்ளது. திருத்துவதால் மீண்டும் வெளியிடப்படாது.',
                                  ),
                                  style: const TextStyle(color: Color(0xFFC62828), fontSize: 12),
                                ),
                              ),
                            const SizedBox(height: 24),
                            Text(
                              t('How was the service?', 'சேவை எப்படி இருந்தது?'),
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
                                  onPressed: () => setState(() => rating = i + 1),
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
                              rating > 0 ? '$rating / 5 ★' : t('Tap a star to rate', 'மதிப்பிட தட்டவும்'),
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
                                labelText: t(
                                  'Your experience (optional)',
                                  'உங்கள் அனுபவம் (விருப்பம்)',
                                ),
                                filled: true,
                                fillColor: const Color(0xFFFBF9FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFE8E5E8)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFE8E5E8)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFF80152C), width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              t(
                                'Your name, rating and review will be public. Avoid sharing phone numbers or private booking details.',
                                'உங்கள் பெயர், மதிப்பீடு மற்றும் விமர்சனம் பொதுவாகக் காட்டப்படும். தொலைபேசி எண் அல்லது தனிப்பட்ட முன்பதிவு விவரங்களைப் பகிர வேண்டாம்.',
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
                                  shadowColor: const Color(0xFF80152C).withValues(alpha: 0.3),
                                ),
                                onPressed: save,
                                child: Text(
                                  saving
                                      ? t('Saving…', 'சேமிக்கிறது…')
                                      : t('Save review', 'விமர்சனத்தைச் சேமி'),
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
                                  t(
                                    'Reload saved review',
                                    'சேமித்த விமர்சனத்தை மீண்டும் ஏற்று',
                                  ),
                                  style: const TextStyle(color: Color(0xFF73737D)),
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
