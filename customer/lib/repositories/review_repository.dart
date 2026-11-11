import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/service_review_model.dart';

class ReviewRepository {
  final SupabaseClient db;
  ReviewRepository({SupabaseClient? client})
    : db = client ?? Supabase.instance.client;
  Future<Map<String, dynamic>> _photos(Map<String, dynamic> row) async {
    final paths = (row['photo_paths'] as List? ?? [])
        .whereType<String>()
        .toList();
    if (paths.isNotEmpty) {
      try {
        final signed = await db.storage
            .from('review-photos')
            .createSignedUrlsResult(paths, 300);
        row['photo_urls'] = signed
            .whereType<SignedUrlSuccess>()
            .map((s) => s.signedUrl)
            .toList();
      } catch (_) {
        row['photo_urls'] = <String>[];
      }
    }
    return row;
  }

  Future<ServiceReviewModel> submitWithPhotos({
    required String bookingId,
    required int rating,
    required String text,
    required int expectedVersion,
    required List<String> existingPaths,
    required List<XFile> newPhotos,
  }) async {
    if (existingPaths.length + newPhotos.length > 5) {
      throw ArgumentError('Choose up to 5 photos.');
    }
    final uploaded = <String>[];
    try {
      for (final photo in newPhotos) {
        final bytes = await photo.readAsBytes();
        if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
          throw ArgumentError('Each photo must be smaller than 5 MB.');
        }
        final jpg = bytes.length > 2 && bytes[0] == 255 && bytes[1] == 216;
        final png =
            bytes.length > 8 &&
            bytes[0] == 137 &&
            bytes[1] == 80 &&
            bytes[2] == 78;
        final webp =
            bytes.length > 12 &&
            String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
            String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
        if (!jpg && !png && !webp) {
          throw ArgumentError('Choose JPG, PNG or WebP photos.');
        }
        final uid = db.auth.currentUser?.id;
        if (uid == null) throw StateError('Sign in again.');
        final ext = jpg
            ? 'jpg'
            : png
            ? 'png'
            : 'webp';
        final path =
            '$uid/$bookingId/${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}.$ext';
        await db.storage
            .from('review-photos')
            .uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                contentType: jpg
                    ? 'image/jpeg'
                    : png
                    ? 'image/png'
                    : 'image/webp',
              ),
            );
        uploaded.add(path);
      }
      final result = await db.rpc(
        'submit_service_review_with_photos',
        params: {
          'p_booking_id': bookingId,
          'p_rating': rating,
          'p_text': text.trim(),
          'p_expected_version': expectedVersion,
          'p_photo_paths': [...existingPaths, ...uploaded],
        },
      );
      return ServiceReviewModel.fromMap(
        Map<String, dynamic>.from(result as Map),
      );
    } catch (_) {
      if (uploaded.isNotEmpty) {
        try {
          await db.storage.from('review-photos').remove(uploaded);
        } catch (_) {}
      }
      rethrow;
    }
  }

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

  Future<BookingReviewContext> bookingContext(String bookingId) async {
    final result = Map<String, dynamic>.from(
      await db.rpc(
        'get_booking_review_context',
        params: {'p_booking_id': bookingId},
      ) as Map,
    );
    if (result['review'] is Map) {
      result['review'] = await _photos(
        Map<String, dynamic>.from(result['review'] as Map),
      );
    }
    return BookingReviewContext.fromMap(result);
  }

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
    int? rating,
  }) async {
    final result = await db.rpc(
      rating == null ? 'get_service_reviews' : 'get_service_reviews_filtered',
      params: {
        'p_service_id': serviceId,
        if (rating == null) 'p_business_id': businessId,
        if (rating == null) 'p_vendor_mode': vendorMode,
        'p_rating': ?rating,
        'p_before_created': before?.createdAt.toUtc().toIso8601String(),
        'p_before_id': before?.id,
        'p_limit': limit,
      },
    );
    return Future.wait(
      (result as List).map(
        (m) async => ServiceReviewModel.fromMap(
          await _photos(Map<String, dynamic>.from(m as Map)),
        ),
      ),
    );
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
