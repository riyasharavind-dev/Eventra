import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/business_model.dart';

class BusinessRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // GET ALL BUSINESSES OF A VENDOR
  // ============================================================

  Future<List<BusinessModel>> getBusinessesByVendor(
    String vendorId,
  ) async {
    final data = await _supabase
        .from('businesses')
        .select()
        .eq('vendor_id', vendorId)
        .eq('is_active', true)
        .order('created_at');

    return (data as List)
        .map(
          (item) => BusinessModel.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  // ============================================================
  // GET CURRENT VENDOR BUSINESSES
  // ============================================================

  Future<List<BusinessModel>> getCurrentVendorBusinesses() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return [];
    }

    return getBusinessesByVendor(user.id);
  }

  // ============================================================
  // GET BUSINESS BY ID
  // ============================================================

  Future<BusinessModel?> getBusinessById(
    String businessId,
  ) async {
    final data = await _supabase
        .from('businesses')
        .select()
        .eq('id', businessId)
        .maybeSingle();

    if (data == null) {
      return null;
    }

    return BusinessModel.fromMap(data);
  }

  // ============================================================
  // CREATE BUSINESS
  // ============================================================

  Future<BusinessModel> createBusiness({
    required String vendorId,
    required String name,
    String? description,
    String? phone,
    String? email,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    final data = await _supabase
        .from('businesses')
        .insert({
          'vendor_id': vendorId,
          'name': name.trim(),
          'description': description,
          'phone': phone,
          'email': email,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
        })
        .select()
        .single();

    return BusinessModel.fromMap(data);
  }

  // ============================================================
  // UPDATE BUSINESS
  // ============================================================

  Future<BusinessModel> updateBusiness({
    required String businessId,
    String? name,
    String? description,
    String? logoUrl,
    String? bannerUrl,
    String? phone,
    String? email,
    String? address,
    double? latitude,
    double? longitude,
    bool? isActive,
  }) async {
    final Map<String, dynamic> updates = {};

    if (name != null) {
      updates['name'] = name.trim();
    }

    if (description != null) {
      updates['description'] = description;
    }

    if (logoUrl != null) {
      updates['logo_url'] = logoUrl;
    }

    if (bannerUrl != null) {
      updates['banner_url'] = bannerUrl;
    }

    if (phone != null) {
      updates['phone'] = phone;
    }

    if (email != null) {
      updates['email'] = email;
    }

    if (address != null) {
      updates['address'] = address;
    }

    if (latitude != null) {
      updates['latitude'] = latitude;
    }

    if (longitude != null) {
      updates['longitude'] = longitude;
    }

    if (isActive != null) {
      updates['is_active'] = isActive;
    }

    updates['updated_at'] = DateTime.now().toIso8601String();

    final data = await _supabase
        .from('businesses')
        .update(updates)
        .eq('id', businessId)
        .select()
        .single();

    return BusinessModel.fromMap(data);
  }

  // ============================================================
  // DEACTIVATE BUSINESS
  // ============================================================

  Future<void> deactivateBusiness(
    String businessId,
  ) async {
    await _supabase
        .from('businesses')
        .update({
          'is_active': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', businessId);
  }

  // ============================================================
  // GET BUSINESS AREA IDS
  // ============================================================

  Future<List<String>> getBusinessCategoryIds(
    String businessId,
  ) async {
    final data = await _supabase
        .from('business_category_nodes')
        .select('category_node_id')
        .eq('business_id', businessId);

    return (data as List)
        .map(
          (item) => item['category_node_id'] as String,
        )
        .toList();
  }

  // ============================================================
  // ADD BUSINESS AREA
  // ============================================================

  Future<void> addBusinessCategory({
    required String businessId,
    required String categoryNodeId,
  }) async {
    await _supabase.from('business_category_nodes').insert({
      'business_id': businessId,
      'category_node_id': categoryNodeId,
    });
  }

  // ============================================================
  // REMOVE BUSINESS AREA
  // ============================================================

  Future<void> removeBusinessCategory({
    required String businessId,
    required String categoryNodeId,
  }) async {
    await _supabase
        .from('business_category_nodes')
        .delete()
        .eq('business_id', businessId)
        .eq('category_node_id', categoryNodeId);
  }

  // ============================================================
  // REPLACE BUSINESS AREAS
  // ============================================================

  Future<void> replaceBusinessCategories({
    required String businessId,
    required List<String> categoryNodeIds,
  }) async {
    await _supabase
        .from('business_category_nodes')
        .delete()
        .eq('business_id', businessId);

    if (categoryNodeIds.isEmpty) {
      return;
    }

    final rows = categoryNodeIds
        .map(
          (categoryNodeId) => {
            'business_id': businessId,
            'category_node_id': categoryNodeId,
          },
        )
        .toList();

    await _supabase
        .from('business_category_nodes')
        .insert(rows);
  }
}