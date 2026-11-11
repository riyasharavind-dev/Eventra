import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Durable account-scoped outbox. Removals remain tombstones until acknowledged.
class CustomerCollectionSync {
  static final _scheduled = <String>{};
  static final _last = <String, DateTime>{};
  static void schedule(
    String key,
    Future<void> Function() task, {
    bool force = false,
  }) {
    if (_scheduled.contains(key)) return;
    if (!force &&
        _last[key] != null &&
        DateTime.now().difference(_last[key]!) < const Duration(seconds: 20)) {
      return;
    }
    _scheduled.add(key);
    serial(task).catchError((Object _) {}).whenComplete(() {
      _scheduled.remove(key);
      _last[key] = DateTime.now();
    });
  }

  static Future<void> _queue = Future.value();
  static Future<T> serial<T>(Future<T> Function() action) {
    final task = _queue.then((_) => action());
    _queue = task.then<void>((_) {}, onError: (Object _, StackTrace stack) {});
    return task;
  }

  static Future<void> change(
    String user,
    String kind,
    String id,
    bool present,
  ) async {
    final p = await SharedPreferences.getInstance();
    final key = 'eventor.collections.outbox.$user';
    final entries = Map<String, dynamic>.from(
      jsonDecode(p.getString(key) ?? '{}') as Map,
    );
    entries['$kind:$id'] = {'kind': kind, 'id': id, 'present': present};
    if (!await p.setString(key, jsonEncode(entries))) {
      throw StateError('Unable to save changes');
    }
  }

  static Future<List<String>?> sync(
    String user,
    String kind,
    List<String> local,
  ) async {
    try {
      final db = Supabase.instance.client;
      if (db.auth.currentUser?.id != user) return null;
      final p = await SharedPreferences.getInstance();
      final key = 'eventor.collections.outbox.$user';
      final entries = Map<String, dynamic>.from(
        jsonDecode(p.getString(key) ?? '{}') as Map,
      );
      final migrated = 'eventor.collections.migrated.$user.$kind';
      if (p.getBool(migrated) != true) {
        for (final id in local) {
          entries.putIfAbsent(
            '$kind:$id',
            () => {'kind': kind, 'id': id, 'present': true},
          );
        }
        await p.setString(key, jsonEncode(entries));
      }
      final ordered = entries.keys.toList()
        ..sort(
          (a, b) => ((entries[a] as Map)['present'] == true ? 1 : 0).compareTo(
            (entries[b] as Map)['present'] == true ? 1 : 0,
          ),
        );
      for (final keyEntry in ordered) {
        if (db.auth.currentUser?.id != user) return null;
        final e = entries[keyEntry] as Map;
        try {
          await db
              .rpc(
                'customer_update_service_collection',
                params: {
                  'p_service_id': e['id'],
                  'p_kind': e['kind'],
                  'p_present': e['present'],
                },
              )
              .timeout(const Duration(seconds: 8));
          entries.remove(keyEntry);
          await p.setString(key, jsonEncode(entries));
        } on PostgrestException catch (e) {
          // A removed/unpublished service must not block the rest of the queue forever.
          if (e.message.contains('Service unavailable') ||
              e.message.contains('Collection limit reached')) {
            entries.remove(keyEntry);
            await p.setString(key, jsonEncode(entries));
          } else {
            rethrow;
          }
        }
      }
      await p.setBool(migrated, true);
      final rows = await db
          .from('customer_service_collections')
          .select('service_id')
          .eq('customer_id', user)
          .eq('kind', kind)
          .order('updated_at')
          .timeout(const Duration(seconds: 8));
      if (db.auth.currentUser?.id != user) return null;
      return rows.map((r) => r['service_id'] as String).toList();
    } catch (_) {
      return null;
    }
  }
}
