import 'package:eventor_customer/widgets/reviews/review_editor_dialog.dart';
import 'package:eventor_customer/screens/extended/my_profile_screen.dart';
import 'package:eventor_customer/widgets/customer_profile_overview.dart';
import 'package:eventor_customer/widgets/common/app_shimmer.dart';
import 'package:eventor_customer/models/account_security_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eventor_customer/models/auth_model.dart';
import 'package:eventor_customer/models/app_settings_model.dart';
import 'package:eventor_customer/models/account_security_model.dart';
import 'package:eventor_customer/models/service_model.dart';
import 'package:eventor_customer/models/service_review_model.dart';
import 'package:eventor_customer/repositories/auth_repository.dart';
import 'package:eventor_customer/repositories/account_security_repository.dart';
import 'package:eventor_customer/repositories/app_settings_repository.dart';
import 'package:eventor_customer/repositories/saved_services_repository.dart';
import 'package:eventor_customer/repositories/review_repository.dart';
import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:eventor_customer/screens/main/me_screen.dart';
import 'package:eventor_customer/screens/extended/account_security_screen.dart';
import 'package:eventor_customer/screens/extended/saved_services_screen.dart';

class ProfileRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<AuthModel?> getAuthUser() async => const AuthModel(
    id: 'customer',
    name: 'Test Customer',
    email: 'test@example.invalid',
    role: 'customer',
  );
}

class SecurityRepository implements AccountSecurityRepository {
  int passwordChanges = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<AccountSecurityModel> load() async => const AccountSecurityModel(
    email: 'test@example.invalid',
    phone: '+919876543210',
  );
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    String? nonce,
  }) async {
    passwordChanges++;
  }
}

class ReviewsRepository implements ReviewRepository {
  int? savedRating;
  String? savedText;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<List<BookingReviewContext>> myReviews() async => const [
    BookingReviewContext(
      bookingId: 'booking',
      serviceId: 'service',
      serviceName: 'Celebration service',
      status: 'completed',
      canReview: true,
    ),
  ];
  @override
  Future<ServiceReviewModel> submit({
    required String bookingId,
    required int rating,
    required String text,
    required int expectedVersion,
  }) async {
    savedRating = rating;
    savedText = text;
    return ServiceReviewModel(
      id: 'review',
      serviceId: 'service',
      vendorId: 'vendor',
      customerName: 'Customer',
      serviceName: 'Celebration service',
      text: text,
      rating: rating,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'Me searches and opens customer screens without a My Bookings entry',
    (tester) async {
      final settings = AppSettingsController(initial: const AppSettingsModel());
      addTearDown(settings.dispose);
      Widget? opened;
      await tester.pumpWidget(
        AppSettingsScope(
          controller: settings,
          child: MaterialApp(
            home: MeScreen(
              repository: ProfileRepository(),
              loadSocialLinks: () async => [],
              onOpen: (screen) => opened = screen,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Test Customer'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'saved');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('me-saved')));
      expect(opened, isA<SavedServicesScreen>());
      await tester.enterText(find.byType(TextField).first, 'bookings');
      await tester.pumpAndSettle();
      expect(find.text('My Bookings'), findsNothing);
      expect(
        find.text('No matching settings. Try another word.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField).first, 'password');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('me-password')));
      expect(opened, isA<AccountSecurityScreen>());
      expect(
        (opened as AccountSecurityScreen).action,
        AccountSecurityAction.password,
      );
    },
  );
  testWidgets(
    'vendor-style customer Me fits narrow screens and keeps profile actions and notification toggle working',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var disabled = 0;
      final settings = AppSettingsController(
        initial: const AppSettingsModel(),
        notificationPermission: () async => true,
        disableNotifications: () async {
          disabled++;
        },
      );
      Widget? opened;
      await tester.pumpWidget(
        AppSettingsScope(
          controller: settings,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: MeScreen(
                repository: ProfileRepository(),
                loadSocialLinks: () async => [],
                onOpen: (screen) => opened = screen,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CustomerProfileOverview), findsOneWidget);
      expect(find.text('test@example.invalid'), findsNothing);
      expect(find.byType(AppShimmer), findsNothing);
      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();
      expect(opened, isA<MyProfileScreen>());
      await tester.tap(
        find.descendant(
          of: find.byType(CustomerProfileOverview),
          matching: find.text('Saved Services'),
        ),
      );
      await tester.pumpAndSettle();
      expect(opened, isA<SavedServicesScreen>());
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('notifications-toggle')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('notifications-toggle')));
      await tester.pumpAndSettle();
      expect(settings.value.notificationsEnabled, false);
      expect(disabled, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      settings.dispose();
    },
  );
  test(
    'Saved services persist and stay separate for different accounts',
    () async {
      const service = ServiceModel(
        id: 'service',
        vendorId: 'vendor',
        categoryNodeId: 'category',
        name: 'Party service',
        slug: 'party',
        price: 500,
        gallery: [],
        isActive: true,
      );
      final first = SavedServicesRepository(userId: 'first');
      await first.setSaved(service, true);
      expect(
        await SavedServicesRepository(userId: 'first').contains('service'),
        true,
      );
      expect(
        await SavedServicesRepository(userId: 'second').getSaved(),
        isEmpty,
      );
      await first.setSaved(service, false);
      expect(await first.getSaved(), isEmpty);
    },
  );
  test(
    'Language choice is persisted and invalid values are rejected',
    () async {
      final repository = AppSettingsRepository();
      await repository.saveLanguage('ta');
      expect((await repository.load()).languageCode, 'ta');
      expect(() => repository.saveLanguage('xx'), throwsArgumentError);
    },
  );
  testWidgets('Password screen blocks mismatched passwords', (tester) async {
    final repository = SecurityRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: AccountSecurityScreen(
          action: AccountSecurityAction.password,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'OldPassword123');
    await tester.enterText(fields.at(1), 'NewPassword123');
    await tester.enterText(fields.at(2), 'Different123');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(repository.passwordChanges, 0);
  });
  testWidgets('Phone screen validates international format', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AccountSecurityScreen(
          action: AccountSecurityAction.phone,
          repository: SecurityRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '123');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Use country code and digits, e.g. +919876543210.'),
      findsOneWidget,
    );
  });
  testWidgets('Booking review editor submits selected stars and text', (
    tester,
  ) async {
    final repository = ReviewsRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                final booking = (await repository.myReviews()).first;
                if (context.mounted) {
                  await showDialog<void>(
                    context: context,
                    builder: (_) => ReviewEditorDialog(
                      booking: booking,
                      repository: repository,
                    ),
                  );
                }
              },
              child: const Text('Give a Review'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Give a Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('4 stars'));
    await tester.enterText(find.byType(TextField), 'Great service');
    await tester.tap(find.text('Save review'));
    await tester.pumpAndSettle();
    expect(repository.savedRating, 4);
    expect(repository.savedText, 'Great service');
  });
}
