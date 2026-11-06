import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/service_review_model.dart';

class ReviewRepository {
  final SupabaseClient db;
  ReviewRepository({SupabaseClient? client})
    : db = client ?? Supabase.instance.client;
  Future<List<BookingReviewContext>> myReviews() async {
    final user = db.auth.currentUser;
    if (user == null) throw StateError('Please sign in again.');
    final results = <BookingReviewContext>[];
    for (var offset = 0; ; offset += 100) {
      final bookings = await db
          .from('bookings')
          .select('id')
          .eq('customer_id', user.id)
          .eq('status', 'completed')
          .order('created_at', ascending: false)
          .order('id')
          .range(offset, offset + 99);
      for (final booking in bookings) {
        results.add(await bookingContext(booking['id'].toString()));
      }
      if (bookings.length < 100) break;
    }
    return results;
  }

  Future<BookingReviewContext> bookingContext(String bookingId) async =>
      BookingReviewContext.fromMap(
        Map<String, dynamic>.from(
          await db.rpc(
            'get_booking_review_context',
            params: {'p_booking_id': bookingId},
          ) as Map,
        ),
      );
  Future<ServiceReviewModel> submit({
    required String bookingId,
    required int rating,
    required String text,
    required int expectedVersion,
  }) async {
    if (rating < 1 || rating > 5) {
      throw ArgumentError('Choose 1 to 5 stars.');
    }
    return ServiceReviewModel.fromMap(
      Map<String, dynamic>.from(
        await db.rpc(
          'submit_service_review',
          params: {
            'p_booking_id': bookingId,
            'p_rating': rating,
            'p_text': text.trim(),
            'p_expected_version': expectedVersion,
          },
        ) as Map,
      ),
    );
  }

  Future<List<ServiceReviewModel>> page({
    String? serviceId,
    String? businessId,
    bool vendorMode = false,
    ServiceReviewModel? before,
    int limit = 20,
  }) async {
    final result = await db.rpc(
      'get_service_reviews',
      params: {
        'p_service_id': serviceId,
        'p_business_id': businessId,
        'p_vendor_mode': vendorMode,
        'p_before_created': before?.createdAt.toUtc().toIso8601String(),
        'p_before_id': before?.id,
        'p_limit': limit,
      },
    );
    return (result as List)
        .map(
          (m) =>
              ServiceReviewModel.fromMap(Map<String, dynamic>.from(m as Map)),
        )
        .toList();
  }

  Future<ReviewSummary> summary({
    String? serviceId,
    String? businessId,
    String? vendorId,
  }) async => ReviewSummary.fromMap(
    Map<String, dynamic>.from(
      await db.rpc(
        'get_review_summary',
        params: {
          'p_service_id': serviceId,
          'p_business_id': businessId,
          'p_vendor_id': vendorId,
        },
      ) as Map,
    ),
  );
  Future<void> reply(ServiceReviewModel review, String text) async {
    await db.rpc(
      'reply_service_review',
      params: {
        'p_review_id': review.id,
        'p_reply': text.trim(),
        'p_expected_version': review.replyVersion,
      },
    );
  }

  Future<void> report(ServiceReviewModel review, String reason) async {
    await db.rpc(
      'report_service_review',
      params: {'p_review_id': review.id, 'p_reason': reason.trim()},
    );
  }
}
