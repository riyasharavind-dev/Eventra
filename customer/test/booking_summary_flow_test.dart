import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_customer/models/booking_draft.dart';
import 'package:eventor_customer/models/service_model.dart';
import 'package:eventor_customer/repositories/booking_repository.dart';
import 'package:eventor_customer/repositories/service_repository.dart';
import 'package:eventor_customer/repositories/customer_address_repository.dart';
import 'package:eventor_customer/screens/extended/booking_screen.dart';
import 'package:eventor_customer/screens/extended/booking_summary_screen.dart';

const services = [
  ServiceModel(
    id: 'one',
    vendorId: 'v1',
    categoryNodeId: 'c',
    name: 'Decoration',
    slug: 'decoration',
    price: 5000,
    gallery: [],
    isActive: true,
  ),
  ServiceModel(
    id: 'two',
    vendorId: 'v2',
    categoryNodeId: 'c',
    name: 'Catering',
    slug: 'catering',
    price: 2000,
    gallery: [],
    isActive: true,
  ),
];

class SummaryServices implements ServiceRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<List<ServiceModel>> getServicesByIds(List<String> ids) async =>
      services;
  @override
  Future<Map<String, dynamic>> getPublicOverview(String id) async => {
    'business_name': 'Demo Business',
    'rating': 4.8,
    'review_count': 23,
  };
}

class ContactAddress extends CustomerAddressRepository {
  @override
  Future<String?> load() async => '12 Main Street, Chennai 600001';
}

class Bookings extends BookingRepository {
  int calls = 0;
  String? venue, time;
  int? guests;
  List<ServiceModel>? selected;
  @override
  Future<void> bookCart({
    Map<String, int> quantities = const {},
    required List<ServiceModel> services,
    required DateTime date,
    required int guests,
    required String eventTime,
    required String location,
    required String requestId,
  }) async {
    calls++;
    venue = location;
    time = eventTime;
    this.guests = guests;
    selected = services;
  }
}

void main() {
  testWidgets(
    'event form precedes final summary and books only on confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = Bookings();
      bool? result;
      final draft = BookingDraft(
        date: DateTime.now().add(const Duration(days: 3)),
        hour: 14,
        minute: 30,
        guests: 100,
        venue: 'Community Hall, Main Road',
        requestId: 'test-summary-flow-request',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingScreen(
                        service: services.first,
                        services: services,
                        initialDraft: draft,
                        bookingRepository: repo,
                        serviceRepository: SummaryServices(),
                        addressRepository: ContactAddress(),
                      ),
                    ),
                  );
                },
                child: const Text('Start booking'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Start booking'));
      await tester.pumpAndSettle();
      expect(find.byType(BookingScreen), findsOneWidget);
      expect(find.text('Confirm Booking'), findsNothing);
      expect(repo.calls, 0);
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.byType(BookingSummaryScreen), findsOneWidget);
      expect(find.text('Confirm Booking'), findsOneWidget);
      expect(find.text('Selected Package'), findsNothing);
      expect(repo.calls, 0);
      await tester.tap(find.text('Edit').first);
      await tester.pumpAndSettle();
      expect(find.byType(BookingScreen), findsOneWidget);
      expect(find.text('Community Hall, Main Road'), findsOneWidget);
      expect(repo.calls, 0);
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm Booking'));
      await tester.pumpAndSettle();
      expect(repo.calls, 1);
      expect(repo.selected!.length, 2);
      expect(repo.guests, 100);
      expect(repo.time, '14:30:00');
      expect(repo.venue, 'Community Hall, Main Road');
      expect(find.text('Your requests have been sent'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(result, true);
      expect(tester.takeException(), isNull);
    },
  );
}
