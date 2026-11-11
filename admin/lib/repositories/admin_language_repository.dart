import 'package:supabase_flutter/supabase_flutter.dart';

class AdminLanguageRepository {
  AdminLanguageRepository({SupabaseClient? client})
    : client = client ?? Supabase.instance.client;
  final SupabaseClient client;
  Future<Map<String, dynamic>> workspace() async => Map<String, dynamic>.from(
    await client.rpc('admin_language_workspace') as Map,
  );
  Future<Map<String, dynamic>> entries(
    String code, {
    String search = '',
    String module = '',
    bool missing = false,
    int offset = 0,
  }) async => Map<String, dynamic>.from(
    await client.rpc(
      'admin_language_entries',
      params: {
        'p_code': code,
        'p_search': search,
        'p_module': module,
        'p_missing': missing,
        'p_offset': offset,
        'p_limit': 40,
      },
    ) as Map,
  );
  Future<void> create(
    String code,
    String name,
    String native,
    String direction,
  ) async {
    await client.rpc(
      'admin_language_create',
      params: {
        'p_code': code,
        'p_name': name,
        'p_native_name': native,
        'p_direction': direction,
      },
    );
  }

  Future<void> update(
    String code,
    String name,
    String native,
    String direction,
    bool enabled,
    int revision,
  ) async {
    await client.rpc(
      'admin_language_update',
      params: {
        'p_code': code,
        'p_name': name,
        'p_native_name': native,
        'p_direction': direction,
        'p_enabled': enabled,
        'p_expected_revision': revision,
      },
    );
  }

  Future<int> save(
    String code,
    Map<String, dynamic> values,
    int revision,
  ) async => (await client.rpc(
    'admin_language_save',
    params: {
      'p_code': code,
      'p_values': values,
      'p_expected_revision': revision,
    },
  ) as num).toInt();
  Future<Map<String, dynamic>> validate(String code) async =>
      Map<String, dynamic>.from(
        await client.rpc('admin_language_validate', params: {'p_code': code})
            as Map,
      );
  Future<Map<String, dynamic>> publish(
    String code,
    int revision,
    bool fallback,
  ) async => Map<String, dynamic>.from(
    await client.rpc(
      'admin_language_publish',
      params: {
        'p_code': code,
        'p_expected_revision': revision,
        'p_allow_english_fallback': fallback,
      },
    ) as Map,
  );
  Future<List<Map<String, dynamic>>> history(String code) async =>
      (await client.rpc(
        'admin_language_history',
        params: {'p_code': code},
      ) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  Future<void> restore(String code, int version, int revision) async {
    await client.rpc(
      'admin_language_restore_draft',
      params: {
        'p_code': code,
        'p_version': version,
        'p_expected_revision': revision,
      },
    );
  }

  Future<Map<String, dynamic>> export(String code) async =>
      Map<String, dynamic>.from(
        await client.rpc('admin_language_export', params: {'p_code': code})
            as Map,
      );
}
