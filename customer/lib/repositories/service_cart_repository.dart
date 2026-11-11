import '../services/app_live_data.dart';
import 'customer_collection_sync.dart';

import 'package:flutter/foundation.dart';

import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceCartRepository {
  static final counts = ValueNotifier<Map<String, int>>({});
  static void _publish(String account, int count) {
    if (counts.value[account] != count) {
      counts.value = {...counts.value, account: count};
    }
  }

  static Future<void> _queue = Future.value();
  String get account =>
      Supabase.instance.client.auth.currentUser?.id ??
      (throw StateError('Please sign in to add services.'));
  Future<List<String>> load({bool refresh = false}) async {
    final id = account;
    final result = await CustomerCollectionSync.serial(() => _load());
    _sync(id, force: refresh);
    return result;
  }

  Future<List<String>> _load() async {
    final id = account;
    final p = await SharedPreferences.getInstance();
    if (account != id) throw StateError('Account changed.');
    final result = (p.getStringList('eventor.customer.cart.$id') ?? [])
        .toSet()
        .take(30)
        .toList();
    _publish(id, result.length);
    return result;
  }

  void _sync(String id, {bool force = false}) =>
      CustomerCollectionSync.schedule('$id:added', () async {
        if (account != id) return;
        final local = await _load();
        final remote = await CustomerCollectionSync.sync(id, 'added', local);
        if (remote == null || account != id) return;
        final p = await SharedPreferences.getInstance();
        await p.setStringList('eventor.customer.cart.$id', remote);
        _publish(id, remote.length);
        if (!listEquals(local, remote)) {
          AppLiveData.instance.invalidate({'own:customer_service_collections'});
        }
      }, force: force);

  Future<void> add(String serviceId) => _edit((ids) {
    if (!ids.contains(serviceId)) {
      if (ids.length >= 30) throw StateError('Your cart can hold 30 services.');
      ids.add(serviceId);
    }
  });
  Future<void> removeAll(Iterable<String> ids) =>
      _edit((items) => items.removeWhere(ids.contains));
  Future<void> _edit(void Function(List<String>) change) {
    final id = account;
    final task = _queue.then(
      (_) => CustomerCollectionSync.serial(() async {
        if (account != id) throw StateError('Account changed.');
        final ids = await _load();
        final before = ids.toSet();
        change(ids);
        final prefs = await SharedPreferences.getInstance();
        if (account != id) throw StateError('Account changed.');
        if (!await prefs.setStringList('eventor.customer.cart.$id', ids)) {
          throw StateError('Unable to save cart. Retry.');
        }
        for (final service in {...before, ...ids}) {
          if (before.contains(service) != ids.contains(service)) {
            await CustomerCollectionSync.change(
              id,
              'added',
              service,
              ids.contains(service),
            );
          }
        }
        _sync(id, force: true);
        if (account == id) _publish(id, ids.length);
      }),
    );
    _queue = task.catchError((Object _) {});
    return task;
  }
}
