import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:customer/models/customer_search_model.dart';
import 'package:customer/repositories/customer_search_repository.dart';
import 'package:customer/screens/extended/search_screen.dart';

CustomerSearchResult result(String name, {bool vendor = false}) =>
    CustomerSearchResult({
      'id': name,
      'name': name,
      'type': vendor ? 'vendors' : 'services',
      'price': 25,
      'pricing_type': 'per_unit',
      'pricing_unit': 'chair',
      'category_name': 'Decoration',
      'service': {'id': name},
    });

class FakeSearch implements CustomerSearchRepository {
  final calls = <String>[];
  final pending = <String, Completer<CustomerSearchPage>>{};
  bool delayed = false, fail = false;
  @override
  Future<List<String>> browseSuggestions() async => [];
  @override
  Future<CustomerSearchPage> search(
    String query, {
    String kind = 'all',
    int offset = 0,
  }) async {
    calls.add('$query:$kind:$offset');
    if (fail) throw StateError('offline');
    if (delayed) {
      final wait = Completer<CustomerSearchPage>();
      pending[query] = wait;
      return wait.future;
    }
    return CustomerSearchPage(
      items: [result('$query result', vendor: kind == 'vendors')],
      hasMore: false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('History is normalized, deduplicated, capped, account isolated and removable', () async {
    final history = CustomerSearchHistoryRepository(accountId: 'one');
    await history.remember('  Wedding   Decor  ');
    await history.remember('wedding decor');
    expect((await history.load()).length, 1);
    expect((await history.load()).single.query, 'wedding decor');
    expect(
      await CustomerSearchHistoryRepository(accountId: 'two').load(),
      isEmpty,
    );
    await Future.wait([
      for (var i = 0; i < 15; i++) history.remember('Query $i'),
    ]);
    expect((await history.load()).length, 12);
    await history.remove('query 14');
    expect((await history.load()).any((r) => r.query == 'Query 14'), isFalse);
    await history.clear();
    expect(await history.load(), isEmpty);
  });
  testWidgets(
    'Recent query submits search, filters vendors and opens a result',
    (tester) async {
      final history = CustomerSearchHistoryRepository(accountId: 'one');
      await history.remember('Wedding');
      final repo = FakeSearch();
      CustomerSearchResult? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerSearchScreen(
            repository: repo,
            historyRepository: history,
            onOpen: (r) => opened = r,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Recent searches'), findsOneWidget);
      await tester.tap(find.text('Wedding'));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'Wedding:all:0');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Vendors'));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'Wedding:vendors:0');
      await tester.tap(find.text('Wedding result'));
      await tester.pumpAndSettle();
      expect(opened?.isVendor, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Debounced search ignores old responses and recovers from failure',
    (tester) async {
      final repo = FakeSearch()..delayed = true;
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerSearchScreen(
            repository: repo,
            historyRepository: CustomerSearchHistoryRepository(
              accountId: 'one',
            ),
            onOpen: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'old');
      await tester.pump(const Duration(milliseconds: 360));
      await tester.enterText(find.byType(TextField), 'new');
      await tester.pump(const Duration(milliseconds: 360));
      repo.pending['new']!.complete(
        CustomerSearchPage(items: [result('New service')], hasMore: false),
      );
      await tester.pumpAndSettle();
      repo.pending['old']!.complete(
        CustomerSearchPage(items: [result('Old service')], hasMore: false),
      );
      await tester.pumpAndSettle();
      expect(find.text('New service'), findsOneWidget);
      expect(find.text('Old service'), findsNothing);
      repo.delayed = false;
      repo.fail = true;
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      repo.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('new result'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
