import 'customer_collection_sync.dart';
import 'service_repository.dart';
import '../services/app_live_data.dart';

import 'dart:async';

import 'recommendation_repository.dart';

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/service_model.dart';

class SavedServicesRepository {
  SavedServicesRepository({String? userId})
    : _userId = userId ?? Supabase.instance.client.auth.currentUser?.id;
  final String? _userId;
  String get _key {
    if (_userId == null) throw StateError('Please sign in again.');
    return 'eventor.customer.saved_services.v1.$_userId';
  }

  Future<List<ServiceModel>> getSaved({bool refresh = false}) async {
    final result = await CustomerCollectionSync.serial(() => _getSaved());
    _sync(force: refresh);
    return result;
  }

  void _sync({bool force = false}) =>
      CustomerCollectionSync.schedule('$_userId:saved', () async {
        final local = await _getSaved();
        final ids = await CustomerCollectionSync.sync(
          _userId!,
          'saved',
          local.map((s) => s.id).toList(),
        );
        if (ids == null) return;
        final fresh = ids.isEmpty
            ? <ServiceModel>[]
            : await ServiceRepository().getServicesByIds(ids);
        if (Supabase.instance.client.auth.currentUser?.id != _userId) return;
        final p = await SharedPreferences.getInstance();
        final values = fresh.map((s) => jsonEncode(s.toMap())).toList();
        if (jsonEncode(p.getStringList(_key)) != jsonEncode(values)) {
          await p.setStringList(_key, values);
          AppLiveData.instance.invalidate({'local_saved_services'});
        }
      }, force: force);
  Future<List<ServiceModel>> _getSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_key) ?? [];
    final services = <ServiceModel>[];
    for (final value in values) {
      try {
        services.add(
          ServiceModel.fromMap(
            Map<String, dynamic>.from(jsonDecode(value) as Map),
          ),
        );
      } catch (_) {
        /* Ignore a damaged local entry. */
      }
    }
    return services;
  }

  Future<bool> contains(String id) async =>
      (await getSaved()).any((service) => service.id == id);
  Future<void> setSaved(ServiceModel service, bool saved) =>
      CustomerCollectionSync.serial(() async {
        final entries = await _getSaved();
        entries.removeWhere((entry) => entry.id == service.id);
        if (saved) entries.insert(0, service);
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.setStringList(
          _key,
          entries.map((entry) => jsonEncode(entry.toMap())).toList(),
        )) {
          throw StateError('Unable to save this service. Please retry.');
        }
        await CustomerCollectionSync.change(
          _userId!,
          'saved',
          service.id,
          saved,
        );
        _sync(force: true);
        AppLiveData.instance.invalidate({'local_saved_services'});
        // Durable local intent syncs to the account; discovery signals are best effort.
        try {
          final recommendations = RecommendationRepository();
          if (recommendations.db.auth.currentUser?.id == _userId) {
            unawaited(
              recommendations.signal(service.id, saved ? 'save' : 'unsave'),
            );
          }
        } catch (_) {
          /* Supabase may be unavailable during offline-only usage. */
        }
      });
}
