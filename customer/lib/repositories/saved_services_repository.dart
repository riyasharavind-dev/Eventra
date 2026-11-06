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

  Future<List<ServiceModel>> getSaved() async {
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
  Future<void> setSaved(ServiceModel service, bool saved) async {
    final entries = await getSaved();
    entries.removeWhere((entry) => entry.id == service.id);
    if (saved) entries.insert(0, service);
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setStringList(
      _key,
      entries.map((entry) => jsonEncode(entry.toMap())).toList(),
    )) {
      throw StateError('Unable to save this service. Please retry.');
    }
  }
}
