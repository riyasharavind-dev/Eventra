import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_connections_model.dart';
import '../models/admin_module.dart';

class AdminConnectionsRepository {
  final SupabaseClient db;
  AdminConnectionsRepository(this.db);
  Future<AdminConnections> inventory() async => AdminConnections.fromMap(
    Map<String, dynamic>.from(
      await db.rpc('admin_connections_inventory') as Map,
    ),
  );
  Future<AdminPage> objects(
    String bucket, {
    String query = '',
    int offset = 0,
  }) async => AdminPage.fromMap(
    Map<String, dynamic>.from(
      await db.rpc(
        'admin_storage_objects',
        params: {
          'p_bucket': bucket,
          'p_query': query,
          'p_offset': offset,
          'p_limit': 30,
        },
      ) as Map,
    ),
  );
  Future<AdminPage> system(String source, {int offset = 0}) async =>
      AdminPage.fromMap(
        Map<String, dynamic>.from(
          await db.rpc(
            'admin_system_records',
            params: {'p_source': source, 'p_offset': offset, 'p_limit': 30},
          ) as Map,
        ),
      );
}
