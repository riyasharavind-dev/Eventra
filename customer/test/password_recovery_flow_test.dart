import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eventor_customer/repositories/password_recovery_repository.dart';
import 'package:eventor_customer/screens/auth/account_recovery_screen.dart';

class RecoveryStub extends PasswordRecoveryRepository {
  int requests = 0;
  bool expired = false;
  String? address;
  @override
  Future<void> request(String email) async {
    requests++;
    address = email;
  }

  @override
  Future<void> verify(String email, String code) async {
    if (expired) {
      throw const AuthException('Token expired', code: 'otp_expired');
    }
  }
}

void main() {
  testWidgets('resend appears only after requesting a reset email', (
    tester,
  ) async {
    final repo = RecoveryStub();
    await tester.pumpWidget(
      MaterialApp(
        home: AccountRecoveryScreen(
          repository: repo,
          emailDeliveryReady: true,
          resendCooldown: Duration.zero,
        ),
      ),
    );
    expect(find.byKey(const ValueKey('recovery-resend')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('recovery-email')),
      'customer@example.com',
    );
    await tester.tap(find.text('Send Reset Email'));
    await tester.pumpAndSettle();
    expect(repo.requests, 1);
    expect(find.text('Resend Email'), findsOneWidget);
    await tester.tap(find.text('Resend Email'));
    await tester.pumpAndSettle();
    expect(repo.requests, 2);
    expect(repo.address, 'customer@example.com');
  });
  testWidgets('resend cooldown blocks repeated requests', (tester) async {
    final repo = RecoveryStub();
    await tester.pumpWidget(
      MaterialApp(
        home: AccountRecoveryScreen(repository: repo, emailDeliveryReady: true),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('recovery-email')),
      'customer@example.com',
    );
    await tester.tap(find.text('Send Reset Email'));
    await tester.pumpAndSettle();
    final button = tester.widget<TextButton>(
      find.byKey(const ValueKey('recovery-resend')),
    );
    expect(button.onPressed, isNull);
    expect(repo.requests, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'expired recovery code keeps resend available and password locked',
    (tester) async {
      final repo = RecoveryStub()..expired = true;
      await tester.pumpWidget(
        MaterialApp(
          home: AccountRecoveryScreen(
            repository: repo,
            emailDeliveryReady: true,
            resendCooldown: Duration.zero,
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('recovery-email')),
        'customer@example.com',
      );
      await tester.tap(find.text('Send Reset Email'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('recovery-code')),
        '12345678',
      );
      await tester.tap(find.text('Verify Code'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'This code expired or is invalid. Request a new email below.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('recovery-password')), findsNothing);
      await tester.tap(find.text('Resend Email'));
      await tester.pumpAndSettle();
      expect(repo.requests, 2);
    },
  );
}
