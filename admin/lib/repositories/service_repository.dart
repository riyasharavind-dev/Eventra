import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/service_model.dart';

class ServiceRepository {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  // ============================================================
  // GET ALL SERVICES
  // ============================================================

  Future<List<ServiceModel>> getServices() async {
    final response = await _supabase
        .from('services')
        .select('''
          id,
          vendor_id,
          category_node_id,
          event_type_id,
          name,
          slug,
          description,
          price,
          gallery,
          is_active,
          created_at,
          updated_at,
          vendors (
            id,
            name,
            email
          ),
          category_nodes (
            id,
            name,
            slug
          ),
          event_types (
            id,
            name,
            slug
          )
        ''')
        .order(
          'created_at',
          ascending: false,
        );

    return (response as List)
        .map(
          (item) => ServiceModel.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  // ============================================================
  // GET SINGLE SERVICE
  // ============================================================

  Future<ServiceModel> getService(
    String serviceId,
  ) async {
    final response = await _supabase
        .from('services')
        .select('''
          id,
          vendor_id,
          category_node_id,
          event_type_id,
          name,
          slug,
          description,
          price,
          gallery,
          is_active,
          created_at,
          updated_at,
          vendors (
            id,
            name,
            email
          ),
          category_nodes (
            id,
            name,
            slug
          ),
          event_types (
            id,
            name,
            slug
          )
        ''')
        .eq('id', serviceId)
        .single();

    return ServiceModel.fromMap(
      Map<String, dynamic>.from(response),
    );
  }

  // ============================================================
  // ACTIVATE / DEACTIVATE
  // ============================================================

  Future<void> toggleService(
    ServiceModel service,
  ) async {
    await _supabase
        .from('services')
        .update({
          'is_active': !service.isActive,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', service.id);
  }

  // ============================================================
  // DELETE SERVICE
  // ============================================================

  Future<void> deleteService(
    String serviceId,
  ) async {
    await _supabase
        .from('services')
        .delete()
        .eq('id', serviceId);
  }
}