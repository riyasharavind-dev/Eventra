import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_customer/models/booking_model.dart';
import 'package:eventor_customer/models/calendar_bookings.dart';
import 'package:eventor_customer/models/app_settings_model.dart';
import 'package:eventor_customer/repositories/booking_repository.dart';
import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:eventor_customer/services/app_live_data.dart';
import 'package:eventor_customer/screens/main/bookings_screen.dart';
import 'package:eventor_customer/screens/extended/eventor_calendar.dart';
import 'package:eventor_customer/screens/extended/booking_details_screen.dart';
import 'package:eventor_customer/widgets/bookings/customer_booking_card.dart';
import 'package:eventor_customer/widgets/bookings/booking_history_card.dart';

class FakeBookings implements BookingRepository {
  List<BookingModel> rows = [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<List<BookingModel>> getMyBookings() async => rows;
  @override
  Future<BookingModel?> getBookingById(String id) async =>
      rows.where((b) => b.id == id).firstOrNull;
}

BookingModel booking(String id, String status, {DateTime? date}) =>
    BookingModel(
      id: id,
      customerId: 'customer',
      vendorId: 'vendor',
      serviceId: id,
      eventDate: date ?? DateTime.now(),
      eventStartTime: '14:00',
      eventEndTime: '16:00',
      location: 'Chennai',
      price: 2500,
      status: status,
      serviceName: id == 'one' ? 'Wedding decoration' : 'Photography',
      vendorName: 'Test Vendor',
      createdAt: DateTime(2026, 1, id == 'one' ? 2 : 1),
    );
void main() {
  test('calendar includes multi-day and historical bookings; midnight end is exclusive', () {
    final b = BookingModel.fromMap({
      'id': 'span',
      'event_date': '2026-10-01',
      'event_end_date': '2026-10-03',
      'event_start_time': '10:00',
      'event_end_time': '00:00',
      'services': {
        'name': 'Decor',
        'gallery': ['image'],
      },
      'vendors': {'name': 'Vendor'},
      'status': 'completed',
    });
    expect(b.serviceGallery, ['image']);
    expect(b.serviceName, 'Decor');
    expect(bookingsOnDay([b], DateTime(2026, 10, 1)).length, 1);
    expect(bookingsOnDay([b], DateTime(2026, 10, 2)).length, 1);
    expect(bookingsOnDay([b], DateTime(2026, 10, 3)), isEmpty);
  });
  testWidgets(
    'customer list matches vendor card layout, searches, opens details and live calendar',
    (tester) async {
      final settings = AppSettingsController(initial: const AppSettingsModel());
      final repo = FakeBookings()
        ..rows = [booking('one', 'completed'), booking('two', 'pending')];
      await tester.pumpWidget(
        AppSettingsScope(
          controller: settings,
          child: MaterialApp(home: BookingsScreen(repository: repo)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CustomerBookingCard), findsNWidgets(2));
      expect(find.text('Accept'), findsNothing);
      expect(find.text('Reject'), findsNothing);
      expect(find.text('Give a Review'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'decoration');
      await tester.pumpAndSettle();
      expect(find.byType(CustomerBookingCard), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('one')));
      await tester.pumpAndSettle();
      expect(find.byType(BookingDetailsScreen), findsOneWidget);
      expect(find.text('My Reviews'), findsNothing);
      expect(find.text('Give a Review'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-booking-calendar')));
      await tester.pumpAndSettle();
      expect(find.byType(EventorCalendar), findsOneWidget);
      await tester.drag(
        find
            .descendant(
              of: find.byType(EventorCalendar),
              matching: find.byType(ListView),
            )
            .first,
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BookingHistoryCard), findsNWidgets(2));
      repo.rows = [booking('two', 'rejected')];
      AppLiveData.instance.invalidate({'own:bookings'});
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.byType(BookingHistoryCard), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(CustomerBookingCard), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      settings.dispose();
    },
  );
  testWidgets('compact cards fit narrow screens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = AppSettingsController(initial: const AppSettingsModel());
    final repo = FakeBookings()..rows = [booking('one', 'accepted')];
    await tester.pumpWidget(
      AppSettingsScope(
        controller: settings,
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: BookingsScreen(repository: repo),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CustomerBookingCard), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    settings.dispose();
  });
}
