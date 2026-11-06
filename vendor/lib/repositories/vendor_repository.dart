import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vendor_model.dart';

class VendorRepository {
  final SupabaseClient _supabase;

  VendorRepository({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  // ============================================================
  // CURRENT USER ID
  // ============================================================

  String _requireUserId() {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('You are not logged in.');
    }

    return user.id;
  }

  // ============================================================
  // GET MY VENDOR
  // ============================================================

  Future<VendorModel?> getMyVendor() async {
    final userId = _requireUserId();

    final response = await _supabase
        .from('vendors')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return VendorModel.fromMap(Map<String, dynamic>.from(response));
  }

  // ============================================================
  // GET VENDOR BY ID
  // ============================================================

  Future<VendorModel?> getVendorById(String vendorId) async {
    final response = await _supabase
        .from('vendors')
        .select()
        .eq('id', vendorId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return VendorModel.fromMap(Map<String, dynamic>.from(response));
  }

  // ============================================================
  // UPDATE PROFILE DETAILS
  // ============================================================

  Future<VendorModel> updatePersonalDetails({
    required String name,
    String? aboutMe,
    String? preferredContactLanguage,
  }) async {
    final data = await _supabase.rpc(
      'update_vendor_personal_details',
      params: {
        'p_name': name.trim(),
        'p_about_me': aboutMe?.trim(),
        'p_preferred_contact_language': preferredContactLanguage,
      },
    );
    return VendorModel.fromMap(Map<String, dynamic>.from(data as Map));
  }

  Future<VendorModel> updateProfileDetails({
    required String name,
    String? phone,
  }) async {
    final userId = _requireUserId();

    final response = await _supabase
        .from('vendors')
        .update({
          'name': name.trim(),
          'phone': phone?.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId)
        .select()
        .single();

    return VendorModel.fromMap(Map<String, dynamic>.from(response));
  }

  // ============================================================
  // UPDATE PROFILE IMAGE URL
  // ============================================================

  Future<VendorModel> updateProfileImage(String imageUrl) async {
    final userId = _requireUserId();

    final response = await _supabase
        .from('vendors')
        .update({
          'profile_image_url': imageUrl.trim().isEmpty ? null : imageUrl.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId)
        .select()
        .single();

    return VendorModel.fromMap(Map<String, dynamic>.from(response));
  }

  // ============================================================
  // PROFILE STORAGE PATH
  // ============================================================

  String _profileStoragePath(String userId) {
    return 'vendors/$userId/profile.jpg';
  }

  // ============================================================
  // UPLOAD PROFILE IMAGE
  // ============================================================

  Future<VendorModel> uploadProfileImageBytes({
    required Uint8List bytes,
    String? fileName,
  }) async {
    final userId = _requireUserId();

    if (bytes.isEmpty) {
      throw Exception('Image data is empty.');
    }

    final String storagePath = _profileStoragePath(userId);

    await _supabase.storage
        .from('profile')
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    final String publicUrl = _supabase.storage
        .from('profile')
        .getPublicUrl(storagePath);

    final String imageUrl =
        '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';

    return updateProfileImage(imageUrl);
  }

  // ============================================================
  // GET STORAGE PATH FROM URL
  // ============================================================

  String? getStoragePathFromUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return null;
    }

    try {
      final Uri uri = Uri.parse(imageUrl);

      const String marker = '/storage/v1/object/public/profile/';

      final String path = uri.path;

      final int index = path.indexOf(marker);

      if (index == -1) {
        return null;
      }

      final String storagePath = path.substring(index + marker.length);

      if (storagePath.isEmpty) {
        return null;
      }

      return Uri.decodeComponent(storagePath);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // DELETE OLD LEGACY PROFILE IMAGE
  // ============================================================

  Future<void> deleteOldProfileImage({String? oldImageUrl}) async {
    if (oldImageUrl == null || oldImageUrl.trim().isEmpty) {
      return;
    }

    final String? oldStoragePath = getStoragePathFromUrl(oldImageUrl);

    if (oldStoragePath == null || oldStoragePath.isEmpty) {
      return;
    }

    final String userId = _requireUserId();

    final String currentStoragePath = _profileStoragePath(userId);

    if (oldStoragePath == currentStoragePath) {
      return;
    }

    try {
      await _supabase.storage.from('profile').remove([oldStoragePath]);
    } catch (_) {
      // Old image deletion should not
      // break successful upload.
    }
  }

  // ============================================================
  // REMOVE PROFILE IMAGE
  // ============================================================

  Future<VendorModel> removeProfileImage() async {
    final String userId = _requireUserId();

    final String storagePath = _profileStoragePath(userId);

    try {
      await _supabase.storage.from('profile').remove([storagePath]);
    } catch (_) {
      // Continue to clear DB.
    }

    return updateProfileImage('');
  }
}
