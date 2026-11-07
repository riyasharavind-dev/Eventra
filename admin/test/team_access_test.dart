import 'package:flutter/material.dart';
import 'package:eventor_admin/repositories/admin_password_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_admin/repositories/team_access_repository.dart';
import 'package:eventor_admin/screens/extended/admin_team_screen.dart';
import 'package:eventor_admin/screens/extended/admin_password_screen.dart';

class FakeTeamRepository implements TeamAccessRepository {
  Map<String, dynamic>? invited;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<Map<String, dynamic>> workspace() async => {
    'members': [
      {
        'id': 'one',
        'name': 'Owner',
        'email': 'owner@example.invalid',
        'access_level': 'owner',
        'is_active': true,
        'last_login': null,
        'permissions': {},
      },
    ],
    'invitations': [],
    'modules': [
      {'name': 'support_faqs', 'label': 'Help FAQs'},
      {'name': 'bookings', 'label': 'Bookings'},
    ],
    'activity': [],
    'email_settings': {},
  };
  @override
  Future<String> invite(
    Map<String, dynamic> values, {
    bool resend = false,
  }) async {
    invited = values;
    return 'Invitation saved. Configure company SMTP before sending.';
  }
}

class ValidationPasswordRepository implements AdminPasswordRepository {
  @override
  bool get needsMfa => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('New admin passwords require at least twelve characters', () {
    expect(adminPasswordError('123456'), isNotNull);
    expect(adminPasswordError('a long private phrase'), isNull);
  });
  testWidgets(
    'Team invitation preserves selected staff view/edit scope and reports pending delivery',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeTeamRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AdminTeamScreen(repository: repo)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Team Members'), findsOneWidget);
      await tester.tap(find.text('Invite Staff'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Support Person',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Work email'),
        'staff@example.invalid',
      );
      await tester.tap(find.text('Help FAQs'));
      await tester.pumpAndSettle();
      final faqRow = find
          .ancestor(of: find.text('Help FAQs'), matching: find.byType(Row))
          .last;
      await tester.tap(
        find.descendant(of: faqRow, matching: find.byType(Checkbox)).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send Invitation'));
      await tester.pumpAndSettle();
      expect(repo.invited?['level'], 'staff');
      expect(repo.invited?['permissions'], {'support_faqs': true});
      expect(
        find.text('Invitation saved. Configure company SMTP before sending.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Password form rejects short passwords and mismatched confirmation before Auth requests',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminPasswordScreen(
            invitation: true,
            repository: ValidationPasswordRepository(),
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New password'),
        'short',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm password'),
        'different',
      );
      await tester.tap(find.text('Save password'));
      await tester.pumpAndSettle();
      expect(find.text('Use at least 12 characters.'), findsOneWidget);
      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
