import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_admin/models/admin_auth_link.dart';
import 'package:eventor_admin/repositories/admin_password_repository.dart';
import 'package:eventor_admin/screens/extended/admin_password_screen.dart';

class ResetFakeRepository implements AdminPasswordRepository {
  @override
  final bool needsMfa;
  String? requestedEmail, savedPassword, savedCode;
  bool signedOut = false;
  ResetFakeRepository({this.needsMfa = false});
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<void> requestReset(String email) async {
    requestedEmail = email;
  }

  @override
  Future<void> savePassword(
    String password, {
    String? code,
    bool invitation = false,
  }) async {
    savedPassword = password;
    savedCode = code;
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

void main() {
  test('Recovery callback recognizes fragment tokens and PKCE codes without treating a hint as authorization', () {
    final implicit = AdminAuthLink.parse(
      Uri.parse(
        'https://example.invalid/?auth_action=recovery#access_token=dummy&type=recovery',
      ),
    );
    expect(implicit.action, 'recovery');
    expect(implicit.hasCredentials, true);
    final pkce = AdminAuthLink.parse(
      Uri.parse('https://example.invalid/?auth_action=recovery&code=dummy'),
    );
    expect(pkce.hasCredentials, true);
    expect(
      AdminAuthLink.parse(
        Uri.parse('https://example.invalid/?auth_action=recovery'),
      ).hasCredentials,
      false,
    );
  });
  test('Expired links and invitation resend callbacks stay distinct', () {
    expect(
      AdminAuthLink.parse(
        Uri.parse(
          'https://example.invalid/?auth_action=recovery#error=access_denied&error_code=otp_expired',
        ),
      ).hasError,
      true,
    );
    expect(
      AdminAuthLink.parse(
        Uri.parse(
          'https://example.invalid/?auth_action=setup#access_token=dummy&type=recovery',
        ),
      ).action,
      'setup',
    );
  });
  testWidgets(
    'Email request explains the one-click link and new-password step',
    (tester) async {
      final repo = ResetFakeRepository();
      await tester.pumpWidget(
        MaterialApp(home: AdminPasswordScreen(forgot: true, repository: repo)),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Work email'),
        'staff@example.invalid',
      );
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(repo.requestedEmail, 'staff@example.invalid');
      expect(find.text('Check your email'), findsOneWidget);
      expect(repo.savedPassword, isNull);
    },
  );
  testWidgets('Password reset shows success then signs out for a fresh login', (
    tester,
  ) async {
    final repo = ResetFakeRepository();
    bool completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AdminPasswordScreen(
          repository: repo,
          onCompleted: () => completed = true,
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New password'),
      'New private phrase 123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm password'),
      'New private phrase 123',
    );
    await tester.tap(find.text('Save password'));
    await tester.pumpAndSettle();
    expect(repo.savedPassword, 'New private phrase 123');
    expect(find.text('Password reset successfully'), findsOneWidget);
    expect(completed, false);
    await tester.tap(find.text('Back to login'));
    await tester.pumpAndSettle();
    expect(repo.signedOut, true);
    expect(completed, true);
  });
  testWidgets(
    'Existing MFA is entered on the password form and cannot be omitted',
    (tester) async {
      final repo = ResetFakeRepository(needsMfa: true);
      await tester.pumpWidget(
        MaterialApp(home: AdminPasswordScreen(repository: repo)),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New password'),
        'New private phrase 123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        'New private phrase 123',
      );
      await tester.tap(find.text('Save password'));
      await tester.pumpAndSettle();
      expect(repo.savedPassword, isNull);
      expect(find.text('Enter the six-digit code'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Authenticator code'),
        '123456',
      );
      await tester.tap(find.text('Save password'));
      await tester.pumpAndSettle();
      expect(repo.savedCode, '123456');
      expect(find.text('Password reset successfully'), findsOneWidget);
    },
  );
}
