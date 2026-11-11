import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer_address.dart';

class CustomerAddressRepository {
  CustomerAddressRepository({this.client});
  final SupabaseClient? client;
  SupabaseClient get db => client ?? Supabase.instance.client;
  String get uid =>
      db.auth.currentUser?.id ??
      (throw StateError('Please sign in to manage your addresses.'));
  Future<String?> load() async {
    final row = await db
        .from('customer_addresses')
        .select('full_address')
        .eq('customer_id', uid)
        .eq('is_active', true)
        .maybeSingle();
    return row?['full_address']?.toString();
  }

  Future<List<CustomerAddress>> list() async {
    final rows = await db
        .from('customer_addresses')
        .select()
        .eq('customer_id', uid)
        .order('is_active', ascending: false)
        .order('created_at');
    return rows.map(CustomerAddress.fromMap).toList();
  }

  Future<List<AddressRegion>> regions(String level, {String? parentId}) async {
    final result = <AddressRegion>[];
    for (var offset = 0; ; offset += 200) {
      var query = db
          .from('administrative_regions')
          .select('id,name')
          .eq('level', level)
          .eq('is_active', true);
      if (parentId != null) query = query.eq('parent_id', parentId);
      final rows = await query
          .order('name')
          .order('id')
          .range(offset, offset + 199);
      result.addAll(rows.map(AddressRegion.fromMap));
      if (rows.length < 200) break;
    }
    return result;
  }

  Future<void> saveAddress({
    String? id,
    required String label,
    required String street,
    required String area,
    required String pin,
    required AddressRegion state,
    required AddressRegion district,
    AddressRegion? subdistrict,
    required bool makeActive,
  }) async {
    await db.rpc(
      'save_customer_address',
      params: {
        'p_id': id,
        'p_label': label,
        'p_address_line': street.trim(),
        'p_local_area': area.trim(),
        'p_pin_code': pin.trim(),
        'p_state_id': state.id,
        'p_district_id': district.id,
        'p_subdistrict_id': subdistrict?.id,
        'p_make_active': makeActive,
      },
    );
  }

  Future<void> activate(String id) async {
    await db.rpc('activate_customer_address', params: {'p_id': id});
  }

  Future<void> remove(String id) async {
    await db.rpc('delete_customer_address', params: {'p_id': id});
  }
}
