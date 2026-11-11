import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/banner_model.dart';

class BannerRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _table = 'banners';

  // ============================================================
  // GET ACTIVE BANNERS
  // ============================================================

  Future<List<BannerModel>> getActiveBanners() async {
    final response = await _supabase
        .from(_table)
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => BannerModel.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  // ============================================================
  // GET ALL ACTIVE BANNERS
  // ============================================================

  Future<BannerModel?> getBannerById(String id) async {
    final response = await _supabase
        .from(_table)
        .select()
        .eq('id', id)
        .eq('is_active', true)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return BannerModel.fromMap(Map<String, dynamic>.from(response));
  }

  // ============================================================
  // GET BANNERS BY ACTION TYPE
  // ============================================================

  Future<List<BannerModel>> getBannersByActionType(String actionType) async {
    final response = await _supabase
        .from(_table)
        .select()
        .eq('is_active', true)
        .eq('action_type', actionType)
        .order('sort_order', ascending: true);

    return (response as List)
        .map((item) => BannerModel.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }
}
