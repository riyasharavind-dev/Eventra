import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vendor_tour_step.dart';

class OnboardingRepository {
  OnboardingRepository({SupabaseClient? client}) : _providedClient = client;
  final SupabaseClient? _providedClient;
  SupabaseClient get _client => _providedClient ?? Supabase.instance.client;
  static const introKey = 'vendor_introduction_v1';
  Future<bool> needsIntroduction() async =>
      !(await SharedPreferences.getInstance()).getBool(introKey).orFalse;
  Future<void> completeIntroduction() async {
    final saved = await (await SharedPreferences.getInstance()).setBool(
      introKey,
      true,
    );
    if (!saved) throw StateError('Unable to save introduction preference');
  }

  String get _uid {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Please sign in again');
    return uid;
  }

  String _key(String uid) => 'vendor_guide_v1_$uid';
  Map<String, dynamic>? _cached(SharedPreferences prefs, String uid) {
    try {
      final raw = prefs.getString(_key(uid));
      return raw == null
          ? null
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<VendorGuideProgress> loadProgress() async {
    final uid = _uid;
    final prefs = await SharedPreferences.getInstance();
    final cached = _cached(prefs, uid);
    try {
      if (_uid != uid) throw StateError('Account changed');
      if (cached?['dirty'] == true) {
        final state = VendorGuideProgress.fromMap(cached!);
        await saveProgress(state, restart: cached['restart'] == true);
      }
      final observedCache = prefs.getString(_key(uid));
      final data = await _client
          .rpc('get_vendor_guide_state', params: {'p_account_id': uid})
          .timeout(const Duration(seconds: 6));
      if (_uid != uid) throw StateError('Account changed');
      final current = _cached(prefs, uid);
      if (current != null &&
          (current['dirty'] == true ||
              prefs.getString(_key(uid)) != observedCache)) {
        return VendorGuideProgress.fromMap(
          current,
          synced: current['dirty'] != true,
        );
      }
      final progress = VendorGuideProgress.fromMap(
        Map<String, dynamic>.from(data as Map),
      );
      await prefs.setString(
        _key(uid),
        jsonEncode({...progress.toMap(), 'dirty': false}),
      );
      return progress;
    } catch (_) {
      if (_uid != uid) rethrow;
      final current = _cached(prefs, uid);
      if (current != null) {
        return VendorGuideProgress.fromMap(current, synced: false);
      }
      rethrow;
    }
  }

  Future<bool> saveProgress(
    VendorGuideProgress progress, {
    bool restart = false,
  }) async {
    final uid = _uid;
    final prefs = await SharedPreferences.getInstance();
    if (_uid != uid) throw StateError('Account changed');
    final payload = {...progress.toMap(), 'dirty': true, 'restart': restart};
    final raw = jsonEncode(payload);
    await prefs.setString(_key(uid), raw);
    try {
      if (_uid != uid) throw StateError('Account changed');
      final result = await _client
          .rpc(
            'save_vendor_guide_progress',
            params: {
              'p_account_id': uid,
              'p_status': progress.status,
              'p_step': progress.step,
              'p_restart': restart,
            },
          )
          .timeout(const Duration(seconds: 6));
      if (_uid == uid && prefs.getString(_key(uid)) == raw) {
        final state = VendorGuideProgress.fromMap(
          Map<String, dynamic>.from(result as Map),
        );
        await prefs.setString(
          _key(uid),
          jsonEncode({...state.toMap(), 'dirty': false}),
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<VendorSetupChecklist> loadChecklist() async {
    final uid = _uid;
    final data = await _client
        .rpc('get_vendor_setup_checklist', params: {'p_account_id': uid})
        .timeout(const Duration(seconds: 8));
    if (_uid != uid) throw StateError('Account changed');
    return VendorSetupChecklist.fromMap(Map<String, dynamic>.from(data as Map));
  }
}

extension on bool? {
  bool get orFalse => this ?? false;
}
