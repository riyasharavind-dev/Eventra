import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_language_pack.dart';

class LanguagePackRepository {
  LanguagePackRepository({SupabaseClient? client}) : _provided = client;
  final SupabaseClient? _provided;
  SupabaseClient get client => _provided ?? Supabase.instance.client;
  static const manifestKey = 'eventor.vendor.i18n.v1.manifest';
  static const indexKey = 'eventor.vendor.i18n.v1.cache_index';
  String key(String code) => 'eventor.vendor.i18n.v1.pack.$code';
  Future<List<AppLanguageOption>> cachedManifest() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(
        manifestKey,
      );
      if (raw == null) return [AppLanguageOption.english];
      return (jsonDecode(raw) as List)
          .map(
            (v) =>
                AppLanguageOption.fromMap(Map<String, dynamic>.from(v as Map)),
          )
          .toList();
    } catch (_) {
      return [AppLanguageOption.english];
    }
  }

  Future<AppLanguagePack?> cachedPack(String code) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(key(code));
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final option = AppLanguageOption.fromMap(
        Map<String, dynamic>.from(map['option'] as Map),
      );
      if (option.code != code) return null;
      return AppLanguagePack.parse(map, option);
    } catch (_) {
      return null;
    }
  }

  Future<List<AppLanguageOption>> fetchManifest() async {
    final data = await client
        .rpc('app_language_manifest')
        .timeout(const Duration(seconds: 10));
    if (data is! List || data.length > 100) {
      throw const FormatException('Invalid language list');
    }
    final options = data
        .map(
          (v) => AppLanguageOption.fromMap(Map<String, dynamic>.from(v as Map)),
        )
        .toList();
    if (options.map((e) => e.code).toSet().length != options.length) {
      throw const FormatException('Duplicate language codes');
    }
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      manifestKey,
      jsonEncode(options.map((v) => v.toMap()).toList()),
    )) {
      throw StateError('Language list could not be cached');
    }
    return options;
  }

  Future<AppLanguagePack> download(AppLanguageOption option) async {
    final data = await client
        .rpc(
          'app_language_pack',
          params: {'p_code': option.code, 'p_version': option.version},
        )
        .timeout(const Duration(seconds: 15));
    return AppLanguagePack.parse(
      Map<String, dynamic>.from(data as Map),
      option,
    );
  }

  Future<void> storePack(
    AppLanguagePack pack, {
    required String preserveCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    // One preference write commits a complete validated snapshot, never fragments.
    if (!await prefs.setString(
      key(pack.option.code),
      jsonEncode(pack.toCache()),
    )) {
      throw StateError('Language pack could not be cached');
    }
    final index = prefs.getStringList(indexKey) ?? [];
    index.remove(pack.option.code);
    index.add(pack.option.code);
    while (index.length > 5) {
      final removable = index.firstWhere(
        (code) => code != preserveCode && code != pack.option.code,
        orElse: () => index.first,
      );
      index.remove(removable);
      await prefs.remove(key(removable));
    }
    await prefs.setStringList(indexKey, index);
  }
}
