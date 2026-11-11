import 'dart:typed_data';

import 'package:eventor_customer/models/app_settings_model.dart';
import 'package:eventor_customer/models/auth_model.dart';
import 'package:eventor_customer/repositories/profile_repository.dart';
import 'package:eventor_customer/screens/extended/my_profile_screen.dart';
import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeProfile implements ProfileRepository {
  AuthModel profile = const AuthModel(
    id: 'customer',
    email: 'customer@example.invalid',
    name: 'Original name',
    role: 'customer',
  );
  int attempts = 0;

  @override
  Future<AuthModel?> getProfile() async => profile;

  @override
  Future<AuthModel> saveProfile({
    required String name,
    required String phone,
    Uint8List? photo,
  }) async {
    if (++attempts == 1) throw StateError('Temporary failure');
    return profile = profile.copyWith(name: name, phone: phone);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'Profile saves edited details and allows retry without losing input',
    (tester) async {
      final settings = AppSettingsController(initial: const AppSettingsModel());
      final repo = FakeProfile();
      await tester.pumpWidget(
        AppSettingsScope(
          controller: settings,
          child: MaterialApp(home: MyProfileScreen(repository: repo)),
        ),
      );
      await tester.pumpAndSettle();

      final name = find.widgetWithText(TextFormField, 'Full name');
      final phone = find.widgetWithText(TextFormField, 'Contact phone');
      final save = find.widgetWithText(FilledButton, 'Save changes');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tester.enterText(name, 'Updated name');
      await tester.enterText(phone, '9876543210');
      await tester.pump();
      expect(repo.attempts, 0);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        find.text('Could not save your profile. Try again.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextFormField>(name).controller!.text,
        'Updated name',
      );

      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repo.profile.name, 'Updated name');
      expect(repo.profile.phone, '+919876543210');
      expect(find.text('Profile updated.'), findsOneWidget);
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
    },
  );
}
