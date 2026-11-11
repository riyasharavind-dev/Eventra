import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/auth_model.dart';

class ProfileRepository {
  ProfileRepository({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;
  final SupabaseClient _supabase;

  static const maxPhotoBytes = 5 * 1024 * 1024;

  Future<AuthModel> saveProfile({
    required String name,
    required String phone,
    Uint8List? photo,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('Sign in required');
    String? avatarUrl;
    if (photo != null) {
      if (photo.isEmpty || photo.length > maxPhotoBytes) {
        throw const FormatException('Invalid profile photo size');
      }
      final (extension, mime) = switch (photo) {
        [255, 216, 255, ...] => ('jpg', 'image/jpeg'),
        [137, 80, 78, 71, 13, 10, 26, 10, ...] => ('png', 'image/png'),
        [82, 73, 70, 70, _, _, _, _, 87, 69, 66, 80, ...] => (
          'webp',
          'image/webp',
        ),
        _ => throw const FormatException('Choose a JPG, PNG or WebP photo'),
      };
      final path =
          'customers/${user.id}/${DateTime.now().microsecondsSinceEpoch}.$extension';
      final bucket = _supabase.storage.from('profile-images');
      await bucket.uploadBinary(
        path,
        photo,
        fileOptions: FileOptions(contentType: mime),
      );
      avatarUrl = bucket.getPublicUrl(path);
    }
    if (_supabase.auth.currentUser?.id != user.id) {
      throw StateError('The signed-in account changed');
    }
    final result = await _supabase.rpc(
      'save_customer_profile',
      params: {'p_name': name, 'p_phone': phone, 'p_avatar_url': avatarUrl},
    );
    return AuthModel.fromMap({
      ...Map<String, dynamic>.from(result as Map),
      'email': user.email,
    });
  }

  Future<AuthModel?> getProfile() async {
    final User? user = _supabase.auth.currentUser;

    if (user == null) {
      return null;
    }

    final dynamic userResult = await _supabase
        .from('users')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (userResult == null) {
      return null;
    }

    final dynamic customerResult = await _supabase
        .from('customers')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    final Map<String, dynamic> combined = {
      ...Map<String, dynamic>.from(userResult),
    };

    if (customerResult != null) {
      combined.addAll(Map<String, dynamic>.from(customerResult));
    }

    combined['email'] = user.email ?? combined['email'];
    return AuthModel.fromMap(combined);
  }

  // =========================================================
  // UPDATE PROFILE
  // =========================================================

  Future<AuthModel?> updateProfile({
    required String name,
    required String phone,
  }) async {
    final User? user = _supabase.auth.currentUser;

    if (user == null) {
      return null;
    }

    final String cleanName = name.trim();
    final String cleanPhone = phone.trim();

    if (cleanName.isEmpty) {
      throw Exception('Name cannot be empty');
    }

    // -------------------------------------------------------
    // UPDATE public.users
    // -------------------------------------------------------

    await _supabase.from('users').update({'name': cleanName}).eq('id', user.id);

    // -------------------------------------------------------
    // UPDATE public.customers
    // -------------------------------------------------------

    await _supabase
        .from('customers')
        .update({
          'name': cleanName,
          'phone': cleanPhone.isEmpty ? null : cleanPhone,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', user.id);

    return await getProfile();
  }

  // =========================================================
  // UPLOAD PROFILE IMAGE
  // =========================================================

  Future<AuthModel?> updateProfileImage(File imageFile) async {
    final User? user = _supabase.auth.currentUser;

    if (user == null) {
      return null;
    }

    if (!await imageFile.exists()) {
      throw Exception('Selected image does not exist');
    }

    final String userId = user.id;

    final String filePath = 'customers/$userId/profile.jpg';

    // -------------------------------------------------------
    // UPLOAD
    // -------------------------------------------------------

    await _supabase.storage
        .from('profile-images')
        .upload(
          filePath,
          imageFile,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
            cacheControl: '3600',
          ),
        );

    // -------------------------------------------------------
    // PUBLIC URL
    // -------------------------------------------------------

    final String baseUrl = _supabase.storage
        .from('profile-images')
        .getPublicUrl(filePath);

    final String publicUrl =
        '$baseUrl?v=${DateTime.now().millisecondsSinceEpoch}';

    // -------------------------------------------------------
    // SAVE URL
    // -------------------------------------------------------

    await _supabase
        .from('customers')
        .update({
          'avatar_url': publicUrl,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId);

    return await getProfile();
  }
}
