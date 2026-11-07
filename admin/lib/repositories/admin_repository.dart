import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_module.dart';

class AdminRepository {
  final SupabaseClient db;
  AdminRepository({SupabaseClient? client})
    : db = client ?? Supabase.instance.client;
  Future<Map<String, dynamic>?> session() async {
    if (db.auth.currentSession == null) {
      return null;
    }
    final data = await db.rpc('admin_context');
    return data == null ? null : Map<String, dynamic>.from(data as Map);
  }

  Future<List<AdminModule>> catalog() async =>
      (await db.rpc('admin_catalog') as List)
          .map((m) => AdminModule.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();
  Future<Map<String, dynamic>> overview() async =>
      Map<String, dynamic>.from(await db.rpc('admin_overview') as Map);
  Future<AdminPage> records(
    String module, {
    String search = '',
    int offset = 0,
    int limit = 30,
    Map<String, dynamic> filters = const {},
  }) async => AdminPage.fromMap(
    Map<String, dynamic>.from(
      await db.rpc(
        'admin_records',
        params: {
          'p_module': module,
          'p_search': search,
          'p_offset': offset,
          'p_limit': limit,
          'p_filters': filters,
        },
      ) as Map,
    ),
  );
  Future<AdminRecord> record(AdminModule module, String id) async =>
      AdminRecord(
        Map<String, dynamic>.from(
          await db.rpc(
            'admin_record',
            params: {'p_module': module.name, 'p_id': id},
          ) as Map,
        ),
      );
  Future<AdminRecord> save(
    AdminModule module,
    Map<String, dynamic> data, {
    AdminRecord? before,
    String? requestId,
  }) async => AdminRecord(
    Map<String, dynamic>.from(
      await db.rpc(
        'admin_save',
        params: {
          'p_module': module.name,
          'p_data': data,
          'p_id': before?.id(module),
          'p_revision': before?.revision,
          'p_request_id': requestId,
        },
      ) as Map,
    ),
  );
  Future<AdminRecord?> action(
    AdminModule module,
    AdminRecord row,
    String action, {
    Map<String, dynamic> values = const {},
  }) async {
    final data = await db.rpc(
      'admin_action',
      params: {
        'p_module': module.name,
        'p_id': row.id(module),
        'p_action': action,
        'p_revision': row.revision,
        'p_values': values,
      },
    );
    return data == null
        ? null
        : AdminRecord(Map<String, dynamic>.from(data as Map));
  }

  Future<Map<String, dynamic>> deleteRecord(
    AdminModule module,
    AdminRecord record,
    String reason,
    String confirmation,
  ) async => Map<String, dynamic>.from(
    await db.rpc(
      'admin_delete_record',
      params: {
        'p_module': module.name,
        'p_id': record.id(module),
        'p_revision': record.revision,
        'p_reason': reason,
        'p_confirmation': confirmation,
      },
    ) as Map,
  );

  Future<void> cleanup(AdminModule module, AdminRecord row) async {
    final byBucket = <String, List<String>>{};
    for (final file in row.values['files'] as List? ?? []) {
      final m = Map<String, dynamic>.from(file as Map);
      byBucket
          .putIfAbsent(m['bucket'] as String, () => [])
          .add(m['path'] as String);
    }
    for (final entry in byBucket.entries) {
      for (var start = 0; start < entry.value.length; start += 50) {
        await db.storage
            .from(entry.key)
            .remove(entry.value.skip(start).take(50).toList());
      }
    }
    await action(module, row, 'cleanup_completed');
  }

  Future<String> signedFile(String bucket, String path) =>
      db.storage.from(bucket).createSignedUrl(path, 300);
  Future<Map<String, String>> upload(
    String module,
    String field,
    Uint8List bytes,
    String filename, {
    String? vendorId,
  }) async {
    final socialIcon = module == 'social_links' && field == 'icon_url';
    if (bytes.isEmpty) {
      throw StateError('Choose an image file.');
    }
    if (socialIcon && bytes.length > 2 * 1024 * 1024) {
      throw StateError('Choose a social icon smaller than 2 MB.');
    }
    if (bytes.length > 8 * 1024 * 1024) {
      throw StateError('Choose an image smaller than 8 MB.');
    }
    String ext, mime;
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      ext = 'jpg';
      mime = 'image/jpeg';
    } else if (bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71) {
      ext = 'png';
      mime = 'image/png';
    } else if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      ext = 'webp';
      mime = 'image/webp';
    } else {
      throw StateError('Choose JPG, PNG or WebP images.');
    }
    final user = db.auth.currentUser?.id;
    if (user == null) {
      throw StateError('Sign in again.');
    }
    final bucket = socialIcon
        ? 'social-icons'
        : module == 'services'
        ? 'service-gallery'
        : module == 'vendors'
        ? 'profile'
        : module == 'businesses'
        ? 'business-media'
        : 'banners';
    final prefix = 'admins/$user/$module';
    final path = '$prefix/${DateTime.now().microsecondsSinceEpoch}-$field.$ext';
    await db.storage
        .from(bucket)
        .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime));
    return {'url': db.storage.from(bucket).getPublicUrl(path), 'path': path};
  }
}
