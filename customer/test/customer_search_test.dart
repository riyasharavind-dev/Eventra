import 'package:eventor_customer/models/app_settings_model.dart';
import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:eventor_customer/widgets/search/filter_sort_sheet.dart';
import 'package:eventor_customer/widgets/common/global_search_bar.dart';
import 'package:eventor_customer/widgets/home_feed_widgets.dart';
import 'package:eventor_customer/widgets/search/result_cards.dart';
import 'package:eventor_customer/screens/extended/result_screen.dart';
import 'package:eventor_customer/widgets/search/customer_search_widgets.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eventor_customer/models/customer_search_model.dart';
import 'package:eventor_customer/repositories/customer_search_repository.dart';
import 'package:eventor_customer/screens/extended/search_screen.dart';

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
  final recorded = <String>[];
  final sortedCalls = <String>[];
  @override
  Future<CustomerSearchPage> searchFiltered(
    String query, {
    String kind = 'all',
    String sort = 'relevance',
    int offset = 0,
  }) async {
    sortedCalls.add('$query:$kind:$sort:$offset');
    return CustomerSearchPage(
      items: [result('$query sorted', vendor: kind == 'vendors')],
      hasMore: false,
    );
  }

  @override
  Future<void> recordSearch(String query) async {
    recorded.add(query);
  }

  final pending = <String, Completer<CustomerSearchPage>>{};
  bool delayed = false, fail = false;
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
  testWidgets('Recent query opens service cards with global search', (
    tester,
  ) async {
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
    expect(find.byType(ResultScreen), findsNothing);
    expect(find.byType(CustomerSearchFilters), findsNothing);
    await tester.tap(find.text('Wedding'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'Wedding:all:0');
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.byType(ResultCards), findsOneWidget);
    expect(find.byType(HomeFeedItemCard), findsOneWidget);
    expect(find.byType(CustomerSearchResultTile), findsNothing);
    expect(find.byType(CustomerSearchFilters), findsNothing);
    expect(find.byType(GlobalSearchBar), findsOneWidget);
    expect(find.text('Results'), findsNothing);
    expect(repo.recorded, ['Wedding']);
    await tester.tap(find.text('Wedding result'));
    await tester.pumpAndSettle();
    expect(opened?.isVendor, isFalse);
    await tester.tap(
      find.descendant(
        of: find.byType(GlobalSearchBar),
        matching: find.byType(TextField),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ResultScreen), findsNothing);
    expect(find.byType(CustomerSearchResultTile), findsNothing);
    expect(find.text('Recent searches'), findsOneWidget);
    expect(repo.recorded, ['Wedding']);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'result chips and vendor-style filter sheet apply and reset backend sorting',
    (tester) async {
      final repo = FakeSearch();
      final settings = AppSettingsController(initial: const AppSettingsModel());
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        AppSettingsScope(
          controller: settings,
          child: MaterialApp(
            home: ResultScreen(
              query: 'Wedding',
              repository: repo,
              onOpen: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Vendors'));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'Wedding:vendors:0');
      await tester.tap(find.byTooltip('Filter & Sort'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchFilterSortSheet), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Price: High to Low').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();
      expect(repo.sortedCalls.last, 'Wedding:vendors:price_high:0');
      await tester.tap(find.byTooltip('Filter & Sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'Wedding:all:0');
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
      expect(repo.recorded, isEmpty);
      repo.delayed = false;
      repo.fail = true;
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      repo.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('new result'), findsOneWidget);
      expect(repo.recorded, ['new']);
      expect(tester.takeException(), isNull);
    },
  );
}
