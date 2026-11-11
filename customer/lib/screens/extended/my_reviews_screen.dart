import 'package:eventor_customer/services/app_settings_controller.dart';
import '../../widgets/common/app_empty_state.dart';

import '../../widgets/reviews/service_review_card.dart';
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
    backgroundColor: const Color(0xFFF8F8FA),
    appBar: AppBar(
      centerTitle: true,
      title: Text(
        AppSettingsScope.translate(context, "customer.my_reviews.cbb118f3"),
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: Color(0xFF17171B),
        ),
      ),
      backgroundColor: const Color(0xFFF8F8FA),
      elevation: 0,
    ),
    body: FutureBuilder<List<BookingReviewContext>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF80152C)),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF80152C),
              ),
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: Text(
                AppSettingsScope.translate(
                  context,
                  "customer.unable_to_load_reviews_retry.24e22b40",
                ),
              ),
            ),
          );
        }
        final rows = snapshot.data ?? [];
        return RefreshIndicator(
          color: const Color(0xFF80152C),
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                AppSettingsScope.translate(
                  context,
                  "customer.share_your_experience_with_services_from_comp.b501c7b3",
                ),
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF73737D),
                ),
              ),
              const SizedBox(height: 16),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: AppEmptyState(
                    icon: Icons.rate_review_outlined,
                    title: AppSettingsScope.translate(
                      context,
                      "customer.your_reviews_and_services_ready_for_review_wi.13f80382",
                    ),
                    message: 'Once your booked events are completed, you can share reviews and photos here.',
                  ),
                ),
              for (final booking in rows)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFF0EDF0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF80152C).withValues(alpha: 0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.serviceName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF17171B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (booking.review != null) ...[
                        Row(
                          children: [
                            for (var i = 1; i <= 5; i++)
                              Icon(
                                i <= booking.review!.rating
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 18,
                                color: const Color(0xFFFFCB48),
                              ),
                            const SizedBox(width: 6),
                            Text(
                              '${booking.review!.rating}/5',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF17171B),
                              ),
                            ),
                          ],
                        ),
                        if (booking.review!.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              booking.review!.text,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: Color(0xFF17171B),
                              ),
                            ),
                          ),
                        ReviewPhotoStrip(urls: booking.review!.photoUrls),
                        if (booking.review!.moderationStatus != 'visible')
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              AppSettingsScope.translate(
                                context,
                                "customer.this_review_is_currently_hidden_by_moderation.b4873d43",
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFC62828),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        if (booking.review!.vendorReply?.isNotEmpty == true)
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F8FA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFF0EDF0)),
                            ),
                            child: Text(
                              AppSettingsScope.translate(
                                context,
                                "customer.vendor_reply_value0.821072a8",
                                args: {"value0": booking.review!.vendorReply},
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF17171B),
                                height: 1.4,
                              ),
                            ),
                          ),
                      ] else
                        Text(
                          AppSettingsScope.translate(
                            context,
                            "customer.give_your_review_from_the_completed_booking_i.3ded8b9f",
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF73737D),
                          ),
                        ),
                      if (booking.review?.vendorReply?.isNotEmpty == true || booking.review == null) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF80152C),
                            side: const BorderSide(color: Color(0xFF80152C)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _edit(booking),
                          icon: const Icon(Icons.rate_review_outlined, size: 16),
                          label: Text(
                            booking.review == null
                                ? 'Write a review'
                                : 'Edit review',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
