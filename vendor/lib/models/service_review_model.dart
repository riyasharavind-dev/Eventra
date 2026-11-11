class ServiceReviewModel {
  final String id,
      serviceId,
      vendorId,
      customerName,
      serviceName,
      text,
      moderationStatus;
  final String? businessId, vendorReply;
  final int rating, version, replyVersion;
  final bool isMine, canReply, reported;
  final DateTime createdAt, updatedAt;
  final DateTime? repliedAt;
  const ServiceReviewModel({
    required this.id,
    required this.serviceId,
    required this.vendorId,
    required this.customerName,
    required this.serviceName,
    required this.text,
    required this.rating,
    required this.createdAt,
    required this.updatedAt,
    this.businessId,
    this.vendorReply,
    this.repliedAt,
    this.version = 1,
    this.replyVersion = 0,
    this.isMine = false,
    this.canReply = false,
    this.reported = false,
    this.moderationStatus = 'visible',
  });
  factory ServiceReviewModel.fromMap(Map<String, dynamic> m) =>
      ServiceReviewModel(
        id: m['id'].toString(),
        serviceId: m['service_id'].toString(),
        vendorId: m['vendor_id'].toString(),
        customerName: m['customer_name']?.toString() ?? 'Customer',
        serviceName: m['service_name']?.toString() ?? '',
        text: m['review_text']?.toString() ?? '',
        rating: (m['rating'] as num).toInt(),
        businessId: m['business_id']?.toString(),
        vendorReply: m['vendor_reply']?.toString(),
        version: (m['version'] as num?)?.toInt() ?? 1,
        replyVersion: (m['reply_version'] as num?)?.toInt() ?? 0,
        isMine: m['is_mine'] == true,
        canReply: false,
        reported: m['reported'] == true,
        moderationStatus: m['moderation_status']?.toString() ?? 'visible',
        createdAt: DateTime.parse(m['created_at'].toString()),
        updatedAt: DateTime.parse(m['updated_at'].toString()),
        repliedAt: DateTime.tryParse(m['replied_at']?.toString() ?? ''),
      );
}

class ReviewSummary {
  final int count;
  final double? average;
  final Map<int, int> stars;
  const ReviewSummary({
    required this.count,
    this.average,
    this.stars = const {},
  });
  factory ReviewSummary.fromMap(Map<String, dynamic> m) => ReviewSummary(
    count: (m['review_count'] as num?)?.toInt() ?? 0,
    average: (m['rating_average'] as num?)?.toDouble(),
    stars: {
      for (final e in (m['stars'] as Map? ?? {}).entries)
        int.parse(e.key.toString()): (e.value as num).toInt(),
    },
  );
}

class BookingReviewContext {
  final String bookingId, serviceId, serviceName, status;
  final bool canReview;
  final ServiceReviewModel? review;
  const BookingReviewContext({
    required this.bookingId,
    required this.serviceId,
    required this.serviceName,
    required this.status,
    required this.canReview,
    this.review,
  });
  factory BookingReviewContext.fromMap(Map<String, dynamic> m) =>
      BookingReviewContext(
        bookingId: m['booking_id'].toString(),
        serviceId: m['service_id'].toString(),
        serviceName: m['service_name']?.toString() ?? '',
        status: m['status'].toString(),
        canReview: m['can_review'] == true,
        review: m['review'] is Map
            ? ServiceReviewModel.fromMap(
                Map<String, dynamic>.from(m['review'] as Map),
              )
            : null,
      );
}
