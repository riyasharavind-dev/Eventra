import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/banner_model.dart';

class BannerRepository {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  static const String _table = 'banners';

  static const String _bucket = 'banners';

  // ============================================================
  // GET BANNERS
  // ============================================================

  Future<List<BannerModel>> getBanners() async {
    final response = await _supabase
        .from(_table)
        .select()
        .order(
          'sort_order',
          ascending: true,
        )
        .order(
          'created_at',
          ascending: false,
        );

    return (response as List)
        .map(
          (item) => BannerModel.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  // ============================================================
  // CREATE BANNER
  // ============================================================

  Future<BannerModel> createBanner({
    required String title,
    String? subtitle,
    required String imageUrl,
    required String imagePath,
    required String actionType,
    String? actionValue,
    required bool isActive,
    required int sortOrder,
  }) async {
    final response = await _supabase
        .from(_table)
        .insert({
          'title': title,
          'subtitle': subtitle,
          'image_url': imageUrl,
          'image_path': imagePath,
          'action_type': actionType,
          'action_value': actionValue,
          'is_active': isActive,
          'sort_order': sortOrder,
        })
        .select()
        .single();

    return BannerModel.fromMap(
      Map<String, dynamic>.from(response),
    );
  }

  // ============================================================
  // UPDATE BANNER
  // ============================================================

  Future<BannerModel> updateBanner({
    required String id,
    required String title,
    String? subtitle,
    required String imageUrl,
    required String imagePath,
    required String actionType,
    String? actionValue,
    required bool isActive,
    required int sortOrder,
  }) async {
    final response = await _supabase
        .from(_table)
        .update({
          'title': title,
          'subtitle': subtitle,
          'image_url': imageUrl,
          'image_path': imagePath,
          'action_type': actionType,
          'action_value': actionValue,
          'is_active': isActive,
          'sort_order': sortOrder,
          'updated_at':
              DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();

    return BannerModel.fromMap(
      Map<String, dynamic>.from(response),
    );
  }

  // ============================================================
  // TOGGLE STATUS
  // ============================================================

  Future<void> toggleBannerStatus(
    BannerModel banner,
  ) async {
    await _supabase
        .from(_table)
        .update({
          'is_active': !banner.isActive,
          'updated_at':
              DateTime.now().toIso8601String(),
        })
        .eq('id', banner.id);
  }

  // ============================================================
  // DELETE BANNER
  // ============================================================

  Future<void> deleteBanner(
    BannerModel banner,
  ) async {
    // Delete image from Storage first.
    if (banner.imagePath.isNotEmpty) {
      try {
        await _supabase.storage
            .from(_bucket)
            .remove([
          banner.imagePath,
        ]);
      } catch (_) {
        // Continue with DB deletion.
      }
    }

    // Delete database record.
    await _supabase
        .from(_table)
        .delete()
        .eq('id', banner.id);
  }

  // ============================================================
  // UPLOAD BANNER IMAGE
  // ============================================================

  Future<String> uploadBannerImage({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await _supabase.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            cacheControl: '3600',
            upsert: true,
          ),
        );

    final String publicUrl =
        _supabase.storage
            .from(_bucket)
            .getPublicUrl(path);

    return publicUrl;
  }

  // ============================================================
  // DELETE IMAGE
  // ============================================================

  Future<void> deleteImage(
    String path,
  ) async {
    if (path.isEmpty) {
      return;
    }

    await _supabase.storage
        .from(_bucket)
        .remove([
      path,
    ]);
  }
}