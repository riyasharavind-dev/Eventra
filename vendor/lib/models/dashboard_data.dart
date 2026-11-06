import 'booking_model.dart';
import 'business_model.dart';
import 'vendor_model.dart';
import 'service_review_model.dart';

class CalendarData {
  final List<BookingModel> bookings;
  final List<BusinessModel> businesses;
  const CalendarData({required this.bookings, required this.businesses});
}

class DashboardOverview {
  final int total,
      pending,
      upcoming,
      completed,
      rejected,
      cancelled,
      activeBusinesses,
      activeServices;
  final ReviewSummary rating;
  final List<ServiceReviewModel> recentReviews;
  final String verificationStatus;
  const DashboardOverview({
    this.total = 0,
    this.pending = 0,
    this.upcoming = 0,
    this.completed = 0,
    this.rejected = 0,
    this.cancelled = 0,
    this.activeBusinesses = 0,
    this.activeServices = 0,
    this.rating = const ReviewSummary(count: 0),
    this.recentReviews = const [],
    this.verificationStatus = 'not_submitted',
  });
  factory DashboardOverview.fromMap(Map<String, dynamic> m) =>
      DashboardOverview(
        total: (m['total'] as num).toInt(),
        pending: (m['pending'] as num).toInt(),
        upcoming: (m['upcoming'] as num).toInt(),
        completed: (m['completed'] as num).toInt(),
        rejected: (m['rejected'] as num).toInt(),
        cancelled: (m['cancelled'] as num).toInt(),
        activeBusinesses: (m['active_businesses'] as num).toInt(),
        activeServices: (m['active_services'] as num).toInt(),
        rating: ReviewSummary.fromMap(
          Map<String, dynamic>.from(m['rating'] as Map),
        ),
        recentReviews: (m['recent_reviews'] as List)
            .map(
              (r) => ServiceReviewModel.fromMap(
                Map<String, dynamic>.from(r as Map),
              ),
            )
            .toList(),
        verificationStatus: m['verification_status'].toString(),
      );
}

class DashboardData extends CalendarData {
  final VendorModel? vendor;
  final DashboardOverview overview;
  const DashboardData({
    required super.bookings,
    required super.businesses,
    required this.vendor,
    required this.overview,
  });
}
