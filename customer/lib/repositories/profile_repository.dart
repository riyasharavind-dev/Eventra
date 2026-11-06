import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/auth_model.dart';

class ProfileRepository {
  ProfileRepository({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;
  final SupabaseClient _supabase;

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
