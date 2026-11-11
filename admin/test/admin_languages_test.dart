import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_admin/repositories/admin_language_repository.dart';
import 'package:eventor_admin/screens/extended/admin_languages_screen.dart';

class LanguageFake implements AdminLanguageRepository {
  String lastSearch = '';
  bool missingOnly = false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<Map<String, dynamic>> workspace() async => {
    'languages': [
      {
        'code': 'ta',
        'name': 'Tamil',
        'native_name': 'Tamil',
        'direction': 'ltr',
        'is_enabled': true,
        'published_version': 1,
        'draft_revision': 1,
        'total': 1,
        'translated': 1,
      },
    ],
    'modules': ['bookings'],
  };
  @override
  Future<Map<String, dynamic>> entries(
    String code, {
    String search = '',
    String module = '',
    bool missing = false,
    int offset = 0,
  }) async {
    lastSearch = search;
    missingOnly = missing;
    return {
      'total': 1,
      'revision': 1,
      'rows': [
        {
          'key': 'common.booking_count.other',
          'default_text': '{count} bookings',
          'translation': '{count} translated bookings',
          'module': 'bookings',
          'notes': 'Preserve count',
          'placeholders': ['count'],
          'invalid': false,
        },
      ],
    };
  }
}

void main() {
  testWidgets(
    'narrow translation workspace respects viewer permissions and searches',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = LanguageFake();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminLanguagesScreen(
              canWrite: false,
              canPublish: false,
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Read-only: translation editing is not permitted.'),
        findsOneWidget,
      );
      // Word rows are lazily built below the mobile toolbar.
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField).first, 'booking');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(repo.lastSearch, 'booking');
      await tester.ensureVisible(find.text('Missing translations'));
      await tester.tap(find.text('Missing translations'));
      await tester.pumpAndSettle();
      expect(repo.missingOnly, true);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('editor can open translation draft with source context', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminLanguagesScreen(
            canWrite: true,
            canPublish: false,
            repository: LanguageFake(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('{count} bookings'));
    await tester.pumpAndSettle();
    expect(find.text('Save draft'), findsOneWidget);
    expect(find.text('Preserve count'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
