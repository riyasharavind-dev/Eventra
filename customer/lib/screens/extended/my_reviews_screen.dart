import '../../services/app_live_data.dart';
import '../../widgets/reviews/review_editor_dialog.dart';

import 'package:flutter/material.dart';

import '../../models/service_review_model.dart';
import '../../repositories/review_repository.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key, this.repository});
  final ReviewRepository? repository;
  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen>
    with LiveDataState<MyReviewsScreen> {
  @override
  Set<String> get liveDatasets => {'own:service_reviews', 'own:bookings'};
  @override
  Future<void> onLiveData(Set<String> changed) async {
    await _load();
  }

  late final ReviewRepository _repo;
  late Future<List<BookingReviewContext>> _future;
  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? ReviewRepository();
    _future = _repo.myReviews();
  }

  Future<void> _load() async {
    final future = _repo.myReviews();
    setState(() {
      _future = future;
    });
    try {
      await future;
    } catch (_) {}
  }

  Future<void> _edit(BookingReviewContext booking) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReviewEditorDialog(booking: booking, repository: _repo),
    );
    if (changed == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Reviews')),
    body: FutureBuilder<List<BookingReviewContext>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: _load,
              child: const Text('Unable to load reviews. Retry'),
            ),
          );
        }
        final rows = snapshot.data ?? [];
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Share your experience with services from completed bookings.',
              ),
              const SizedBox(height: 16),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Your reviews and services ready for review will appear here after a booking is completed.',
                  ),
                ),
              for (final booking in rows)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.serviceName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (booking.review != null) ...[
                          Text('★ ${booking.review!.rating}/5'),
                          Text(booking.review!.text),
                          if (booking.review!.moderationStatus != 'visible')
                            const Text(
                              'This review is currently hidden by moderation.',
                            ),
                          if (booking.review!.vendorReply?.isNotEmpty == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'Vendor reply: ${booking.review!.vendorReply}',
                              ),
                            ),
                        ] else
                          const Text('You have not reviewed this service yet.'),
                        if (booking.canReview)
                          TextButton.icon(
                            onPressed: () => _edit(booking),
                            icon: const Icon(Icons.rate_review_outlined),
                            label: Text(
                              booking.review == null
                                  ? 'Write a review'
                                  : 'Edit review',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
