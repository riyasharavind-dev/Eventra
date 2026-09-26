import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vendor_model.dart';

class VendorRepository {
  VendorRepository();

  final SupabaseClient _supabase =
      Supabase.instance.client;

  // ============================================================
  // GET ALL VENDORS
  // ============================================================

  Future<List<VendorModel>> getVendors() async {
    final response = await _supabase
        .from('vendors')
        .select(
          'id, name, email, created_at',
        )
        .order(
          'created_at',
          ascending: false,
        );

    return (response as List)
        .map(
          (item) => VendorModel.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  // ============================================================
  // GET SINGLE VENDOR
  // ============================================================

  Future<VendorModel> getVendor(
    String vendorId,
  ) async {
    final response = await _supabase
        .from('vendors')
        .select(
          'id, name, email, created_at',
        )
        .eq('id', vendorId)
        .single();

    return VendorModel.fromMap(
      Map<String, dynamic>.from(response),
    );
  }

  // ============================================================
  // DELETE VENDOR
  // ============================================================

  Future<void> deleteVendor(
    String vendorId,
  ) async {
    await _supabase
        .from('vendors')
        .delete()
        .eq('id', vendorId);
  }
}