import 'package:eventor_customer/screens/auth/customer_auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_customer/models/app_settings_model.dart';
import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:eventor_customer/screens/main/bookings_screen.dart';
import 'package:eventor_customer/screens/extended/customer_notifications_screen.dart';
import 'package:eventor_customer/widgets/auth/login_required_dialog.dart';
import 'package:eventor_customer/widgets/customer_profile_overview.dart';

void main() {
  for (final page in <Widget>[
    const BookingsScreen(),
    const CustomerNotificationsScreen(),
  ]) {
    testWidgets('Guest can browse ${page.runtimeType} without login gate', (
      tester,
    ) async {
      final settings = AppSettingsController(initial: const AppSettingsModel());
      await tester.pumpWidget(
        AppSettingsScope(
          controller: settings,
          child: MaterialApp(home: page),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CustomerLoginDialog), findsNothing);
      expect(find.text('Log in'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(
        page is BookingsScreen
            ? find.byKey(const ValueKey('open-booking-calendar'))
            : find.byIcon(Icons.settings_outlined),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CustomerLoginDialog), findsOneWidget);
      await tester.tap(find.text('Maybe Later'));
      await tester.pumpAndSettle();
      expect(find.byType(page.runtimeType), findsOneWidget);
    });
  }
  testWidgets('Guest profile opens login and signup directly', (tester) async {
    final settings = AppSettingsController(initial: const AppSettingsModel());
    await tester.pumpWidget(
      AppSettingsScope(
        controller: settings,
        child: MaterialApp(
          home: Scaffold(
            body: CustomerProfileOverview(
              user: null,
              isGuest: true,
              onEdit: () {},
              onSaved: () {},
            ),
          ),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('customer-profile-overview')),
      findsOneWidget,
    );
    expect(find.text('Hello, Guest'), findsOneWidget);
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    final auth = find.byType(CustomerAuthScreen);
    expect(tester.widget<CustomerAuthScreen>(auth).signup, isFalse);
    expect(find.byType(CustomerLoginDialog), findsNothing);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
    expect(tester.widget<CustomerAuthScreen>(auth).signup, isTrue);
    expect(find.byType(CustomerLoginDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
