import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/service_model.dart';

class ServiceRepository {
  final SupabaseClient _supabase;

  ServiceRepository({
    SupabaseClient? supabase,
  }) : _supabase =
            supabase ?? Supabase.instance.client;

  // ============================================================
  // GET ACTIVE SERVICES
  // ============================================================

  Future<List<ServiceModel>>
      getActiveServices() async {
    final response = await _supabase
        .from('services')
        .select('''
          id,
          vendor_id,
          category_node_id,
          name,
          slug,
          description,
          price,
          gallery,
          is_active,
          created_at,
          updated_at,
          category_nodes (
            id,
            name,
            slug,
            parent_id
          )
        ''')
        .eq(
          'is_active',
          true,
        )
        .order(
          'created_at',
          ascending: false,
        );

    return (response as List)
        .map(
          (item) =>
              ServiceModel.fromMap(
            Map<String, dynamic>.from(
              item,
            ),
          ),
        )
        .toList();
  }

  // ============================================================
  // GET SERVICE BY ID
  // ============================================================

  Future<ServiceModel?>
      getServiceById(
    String serviceId,
  ) async {
    final response = await _supabase
        .from('services')
        .select('''
          id,
          vendor_id,
          category_node_id,
          name,
          slug,
          description,
          price,
          gallery,
          is_active,
          created_at,
          updated_at,
          category_nodes (
            id,
            name,
            slug,
            parent_id
          )
        ''')
        .eq(
          'id',
          serviceId,
        )
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return ServiceModel.fromMap(
      Map<String, dynamic>.from(
        response,
      ),
    );
  }
}