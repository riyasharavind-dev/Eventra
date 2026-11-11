import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_customer/models/booking_model.dart';
import 'package:eventor_customer/models/app_settings_model.dart';
import 'package:eventor_customer/models/service_review_model.dart';
import 'package:eventor_customer/repositories/booking_repository.dart';
import 'package:eventor_customer/repositories/review_repository.dart';
import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:eventor_customer/widgets/bookings/customer_booking_card.dart';
import 'package:eventor_customer/widgets/notifications/customer_notification_card.dart';
import 'package:eventor_customer/widgets/reviews/service_reviews_section.dart';

BookingModel booking(bool complete) => BookingModel(
  id: 'booking',
  customerId: 'customer',
  vendorId: 'vendor',
  serviceId: 'service',
  eventDate: DateTime(2026, 1, 1),
  location: 'Chennai',
  price: 5000,
  status: complete ? 'completed' : 'accepted',
  vendorCompletedAt: DateTime(2026, 1, 2),
  customerCompletedAt: complete ? DateTime(2026, 1, 3) : null,
  serviceName: 'Decoration',
);

class CompletionRepo extends BookingRepository {
  bool complete = false;
  int acknowledgements = 0;
  @override
  Future<void> acknowledgeCompletion(String id) async {
    acknowledgements++;
    complete = true;
  }
}

class ReviewRepo implements ReviewRepository {
  final filters = <int?>[];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<List<ServiceReviewModel>> page({
    String? serviceId,
    String? businessId,
    bool vendorMode = false,
    ServiceReviewModel? before,
    int limit = 20,
    int? rating,
  }) async {
    filters.add(rating);
    return [
      for (final stars in [5, 4])
        if (rating == null || stars == rating)
          ServiceReviewModel(
            id: 'review-$stars',
            serviceId: 'service',
            vendorId: 'vendor',
            customerName: 'Customer',
            serviceName: 'Decoration',
            text: '$stars-star comment',
            rating: stars,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
    ];
  }

  @override
  Future<ReviewSummary> summary({
    String? serviceId,
    String? businessId,
    String? vendorId,
  }) async => const ReviewSummary(count: 2, average: 4.5, stars: {5: 1, 4: 1});
}

void main() {
  testWidgets('review unlocks on booking card only after acknowledgement', (
    tester,
  ) async {
    final repo = CompletionRepo();
    var reviewed = 0;
    final settings = AppSettingsController(initial: const AppSettingsModel());
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      AppSettingsScope(
        controller: settings,
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: CustomerBookingCard(
                  booking: booking(repo.complete),
                  busy: false,
                  onOpen: () {},
                  repository: repo,
                  onAcknowledged: () => setState(() {}),
                  onReview: () => reviewed++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Confirm Completion'), findsOneWidget);
    expect(find.text('Give a Review'), findsNothing);
    await tester.tap(find.text('Confirm Completion'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, completed'));
    await tester.pumpAndSettle();
    expect(repo.acknowledgements, 1);
    expect(find.text('Give a Review'), findsOneWidget);
    await tester.tap(find.text('Give a Review'));
    expect(reviewed, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'completion request appears in notifications without review button',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomerNotificationCard(
              booking: booking(false),
              timeLabel: '10:00 AM',
              unread: true,
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.text('Confirm Event Completion'), findsOneWidget);
      expect(find.text('Confirm Completion'), findsOneWidget);
      expect(find.text('Give a Review'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('star reviews open in popup and all reviews open in a screen', (
    tester,
  ) async {
    final repo = ReviewRepo();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ServiceReviewsSection(
              serviceId: 'service',
              repository: repo,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Review a completed booking'), findsNothing);
    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();
    expect(repo.filters.last, 4);
    expect(find.text('4-star comment'), findsOneWidget);
    expect(find.text('5-star comment'), findsNothing);
    expect(find.text('4-star reviews'), findsOneWidget);
    await tester.tap(find.byTooltip('Close reviews'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View all reviews (2)'));
    await tester.pumpAndSettle();
    expect(find.text('4-star comment'), findsOneWidget);
    expect(find.text('5-star comment'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
