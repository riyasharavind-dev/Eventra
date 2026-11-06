import '../utils/auth_error_message.dart';

import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/auth_model.dart';
import 'profile_repository.dart';

class AuthRepository {
  Future<void> validateAccountRole() async {
    if (_supabase.auth.currentSession == null) {
      throw const AccountAccessException('Please sign in to continue.');
    }
    final role = await _supabase.rpc('get_my_account_role');
    if (role != 'customer') {
      await _supabase.auth.signOut(scope: SignOutScope.local);
      throw const AccountAccessException(
        'This account cannot sign in to the Customer app. Please use a customer account.',
      );
    }
  }

  final SupabaseClient _supabase = Supabase.instance.client;

  // =========================================================
  // SIGN UP
  // =========================================================

  Future<AuthResponse> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'name': name.trim(), 'role': 'customer'},
    );
  }

  // =========================================================
  // SIGN IN
  // =========================================================

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    await validateAccountRole();
    return response;
  }

  // =========================================================
  // CURRENT USER
  // =========================================================

  User? get currentUser {
    return _supabase.auth.currentUser;
  }

  // =========================================================
  // CURRENT SESSION
  // =========================================================

  Session? get currentSession {
    return _supabase.auth.currentSession;
  }

  // =========================================================
  // AUTHENTICATED
  // =========================================================

  bool get isAuthenticated {
    return _supabase.auth.currentSession != null;
  }

  // =========================================================
  // GET CURRENT AUTH PROFILE
  // =========================================================

  Future<AuthModel?> getAuthUser() =>
      ProfileRepository(client: _supabase).getProfile();
  Future<AuthModel?> updateProfile({
    required String name,
    required String phone,
  }) =>
      ProfileRepository(client: _supabase)
          .updateProfile(name: name, phone: phone);
  Future<AuthModel?> updateProfileImage(File imageFile) =>
      ProfileRepository(client: _supabase).updateProfileImage(imageFile);
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // =========================================================
  // AUTH STATE
  // =========================================================

  Stream<AuthState> get authStateChanges {
    return _supabase.auth.onAuthStateChange;
  }
}
