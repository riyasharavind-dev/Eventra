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
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !saving,
      child: VendorPageScaffold(
        appBar: AppBar(
          title: Text(
            data?.review == null
                ? t('Write a Review', 'விமர்சனம் எழுது')
                : t('Edit Review', 'விமர்சனத்தைத் திருத்து'),
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
                        child: Text(t('Retry', 'மீண்டும் முயற்சி')),
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
                    Text(
                      data!.serviceName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    if (!data!.canReview)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            t(
                              'Only the customer of a completed booking can review this service.',
                              'முடிந்த முன்பதிவின் வாடிக்கையாளர் மட்டுமே இந்த சேவையை மதிப்பிட முடியும்.',
                            ),
                          ),
                        ),
                      )
                    else ...[
                      Text(
                        t(
                          'Verified completed booking',
                          'சரிபார்க்கப்பட்ட முடிந்த முன்பதிவு',
                        ),
                        style: TextStyle(color: colors.primary),
                      ),
                      if (data!.review?.moderationStatus == 'hidden')
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(
                            t(
                              'This review is hidden by moderation. Editing does not publish it again.',
                              'இந்த விமர்சனம் நிர்வாகத்தால் மறைக்கப்பட்டுள்ளது. திருத்துவதால் மீண்டும் வெளியிடப்படாது.',
                            ),
                            style: TextStyle(color: colors.error),
                          ),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        t('How was the service?', 'சேவை எப்படி இருந்தது?'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        children: List.generate(
                          5,
                          (i) => IconButton(
                            tooltip: '${i + 1} / 5',
                            onPressed: () => setState(() => rating = i + 1),
                            icon: Icon(
                              i < rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: colors.primary,
                              size: 34,
                            ),
                          ),
                        ),
                      ),
                      Text('$rating / 5'),
                      const SizedBox(height: 24),
                      TextField(
                        controller: text,
                        maxLines: 6,
                        maxLength: 2000,
                        decoration: InputDecoration(
                          labelText: t(
                            'Your experience (optional)',
                            'உங்கள் அனுபவம் (விருப்பம்)',
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        t(
                          'Your name, rating and review will be public. Avoid sharing phone numbers or private booking details.',
                          'உங்கள் பெயர், மதிப்பீடு மற்றும் விமர்சனம் பொதுவாகக் காட்டப்படும். தொலைபேசி எண் அல்லது தனிப்பட்ட முன்பதிவு விவரங்களைப் பகிர வேண்டாம்.',
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: save,
                        child: Text(
                          saving
                              ? t('Saving…', 'சேமிக்கிறது…')
                              : t('Save review', 'விமர்சனத்தைச் சேமி'),
                        ),
                      ),
                      TextButton(
                        onPressed: reload,
                        child: Text(
                          t(
                            'Reload saved review',
                            'சேமித்த விமர்சனத்தை மீண்டும் ஏற்று',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
