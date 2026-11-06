import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/service_model.dart';

class ServiceRepository {
  ServiceRepository({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;
  final SupabaseClient _supabase;
  static const _fields =
      'id,vendor_id,category_node_id,name,slug,description,price,pricing_type,pricing_unit,gallery,is_active,created_at,updated_at,category_nodes(id,name,slug,parent_id)';
  Future<List<ServiceModel>> getActiveServices() async {
    final services = <ServiceModel>[];
    for (var offset = 0; ; offset += 200) {
      final rows = await _supabase
          .from('services')
          .select(_fields)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .order('id')
          .range(offset, offset + 199);
      services.addAll(rows.map(ServiceModel.fromMap));
      if (rows.length < 200) break;
    }
    return services;
  }

  Future<ServiceModel?> getServiceById(String serviceId) async {
    final row = await _supabase
        .from('services')
        .select(_fields)
        .eq('id', serviceId)
        .maybeSingle();
    return row == null ? null : ServiceModel.fromMap(row);
  }
}
