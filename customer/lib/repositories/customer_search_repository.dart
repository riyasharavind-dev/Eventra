import 'feed_card_location.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer_search_model.dart';

class CustomerSearchRepository {
  CustomerSearchRepository({SupabaseClient? client})
    : db = client ?? Supabase.instance.client;
  final SupabaseClient db;
  Future<CustomerSearchPage> search(
    String query, {
    String kind = 'all',
    int offset = 0,
  }) async => CustomerSearchPage.fromMap(
    await addCardLocations(
      db,
      Map<String, dynamic>.from(
        await db.rpc(
          'customer_search',
          params: {
            'p_query': normalizeSearch(query),
            'p_kind': kind,
            'p_offset': offset,
            'p_limit': 20,
          },
        ) as Map,
      ),
    ),
  );
  Future<CustomerSearchPage> searchFiltered(
    String query, {
    String kind = 'all',
    String sort = 'relevance',
    int offset = 0,
  }) async => CustomerSearchPage.fromMap(
    await addCardLocations(
      db,
      Map<String, dynamic>.from(
        await db.rpc(
          'customer_search_filtered',
          params: {
            'p_query': normalizeSearch(query),
            'p_kind': kind,
            'p_sort': sort,
            'p_offset': offset,
            'p_limit': 20,
          },
        ) as Map,
      ),
    ),
  );
  Future<CustomerSearchPage> categoryResults(
    String categoryId, {
    String kind = 'all',
    String sort = 'relevance',
    int offset = 0,
  }) async => CustomerSearchPage.fromMap(
    await addCardLocations(
      db,
      Map<String, dynamic>.from(
        await db.rpc(
          'customer_category_results',
          params: {
            'p_category_id': categoryId,
            'p_kind': kind,
            'p_sort': sort,
            'p_offset': offset,
            'p_limit': 20,
          },
        ) as Map,
      ),
    ),
  );
  Future<void> recordSearch(String query) async {
    if (db.auth.currentUser == null) return;
    await db.rpc(
      'customer_record_category_search',
      params: {'p_query': normalizeSearch(query)},
    );
  }

  CustomerSearchHistoryRepository history() => CustomerSearchHistoryRepository(
    accountId: db.auth.currentUser?.id ?? 'guest',
  );
}

class CustomerSearchHistoryRepository {
  CustomerSearchHistoryRepository({required String accountId})
    : _key = 'eventor.customer.search_history.v1.$accountId';
  final String _key;
  Future<void> _pending = Future<void>.value();
  Future<List<RecentCustomerSearch>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final seen = <String>{};
      return (jsonDecode(raw) as List)
          .whereType<Map>()
          .map(
            (m) => RecentCustomerSearch.fromMap(Map<String, dynamic>.from(m)),
          )
          .where(
            (s) =>
                s.query.length >= 2 &&
                s.query.length <= 80 &&
                seen.add(s.query.toLowerCase()),
          )
          .take(12)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<RecentCustomerSearch>> _update(
    List<RecentCustomerSearch> Function(List<RecentCustomerSearch>) update,
  ) {
    final operation = _pending.then((_) async {
      final next = update(await load());
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(
        _key,
        jsonEncode(next.map((s) => s.toMap()).toList()),
      )) {
        throw StateError('Unable to save search history.');
      }
      return next;
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }

  Future<List<RecentCustomerSearch>> remember(String value) {
    final query = normalizeSearch(value);
    if (query.length < 2 || query.length > 80) return load();
    return _update(
      (rows) => [
        RecentCustomerSearch(query: query, searchedAt: DateTime.now()),
        ...rows.where((row) => row.query.toLowerCase() != query.toLowerCase()),
      ].take(12).toList(),
    );
  }

  Future<List<RecentCustomerSearch>> remove(String query) => _update(
    (rows) => rows
        .where((row) => row.query.toLowerCase() != query.toLowerCase())
        .toList(),
  );
  Future<List<RecentCustomerSearch>> clear() => _update((_) => []);
}
