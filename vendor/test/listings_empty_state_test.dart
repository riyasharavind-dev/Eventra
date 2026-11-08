import 'package:eventor_vendor/services/app_live_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eventor_vendor/models/app_settings_model.dart';
import 'package:eventor_vendor/models/service_model.dart';
import 'package:eventor_vendor/repositories/service_repository.dart';
import 'package:eventor_vendor/screens/main/listings_screen.dart';
import 'package:eventor_vendor/services/app_settings_controller.dart';

class EmptyServices extends ServiceRepository {
  EmptyServices(SupabaseClient client) : super(supabase: client);
  @override
  Future<List<ServiceModel>> getMyServices() async => [];
}

void main() {
  late SupabaseClient client;
  late AppSettingsController settings;
  setUp(() {
    client = SupabaseClient('https://example.supabase.co', 'test-key');
    settings = AppSettingsController(initial: const AppSettingsModel());
  });
  tearDown(() async {
    settings.dispose();
    await client.dispose();
  });
  Future<void> page(
    WidgetTester tester,
    Future<List<Map<String, dynamic>>> Function() load,
  ) async {
    await tester.pumpWidget(
      AppSettingsScope(
        controller: settings,
        child: MaterialApp(
          home: ListingsScreen(
            client: client,
            repository: EmptyServices(client),
            loadBusinesses: load,
            loadMetrics: () async => {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Business changes update the open listings screen without manual reload',
    (tester) async {
      var businesses = <Map<String, dynamic>>[];
      await page(tester, () async => businesses);
      expect(find.text('Add a business to get started'), findsOneWidget);
      businesses = [
        {'id': 'b', 'name': 'Live business', 'is_active': true},
      ];
      AppLiveData.instance.invalidate({'own:businesses'});
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('No services yet'), findsOneWidget);
      expect(find.text('Add a business to get started'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('new vendor sees add business', (tester) async {
    await page(tester, () async => []);
    expect(find.text('Add a business to get started'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add a business'), findsOneWidget);
    expect(find.text('No services yet'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('add-service-fab')));
    await tester.pumpAndSettle();
    expect(find.text('Add a service'), findsOneWidget);
    expect(find.text('Add a business'), findsNWidgets(2));
  });
  testWidgets('inactive business also requires an active business', (
    tester,
  ) async {
    await page(
      tester,
      () async => [
        {'id': 'b', 'name': 'Business', 'is_active': false},
      ],
    );
    expect(find.text('Add a business to get started'), findsOneWidget);
  });
  testWidgets('active business without listings gets service empty state', (
    tester,
  ) async {
    await page(
      tester,
      () async => [
        {'id': 'b', 'name': 'Business', 'is_active': true},
      ],
    );
    expect(find.text('No services yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add Service'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('add-service-fab')));
    await tester.pumpAndSettle();
    expect(find.text('Add a service'), findsOneWidget);
    expect(find.text('Add a business'), findsOneWidget);
    expect(find.text('Add a business to get started'), findsNothing);
  });
  testWidgets('business failure shows retry instead of onboarding', (
    tester,
  ) async {
    await page(tester, () async => throw Exception('offline'));
    expect(find.text('Could not load businesses'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Add a business to get started'), findsNothing);
  });
}
