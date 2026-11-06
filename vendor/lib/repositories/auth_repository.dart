import '../utils/auth_error_message.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/auth_model.dart';

class AuthRepository {
  Future<void> validateAccountRole() async {
    if (_supabase.auth.currentSession == null) {
      throw const AccountAccessException('Please sign in to continue.');
    }
    final role = await _supabase.rpc('get_my_account_role');
    if (role != 'vendor') {
      await _supabase.auth.signOut(scope: SignOutScope.local);
      throw const AccountAccessException(
        'This account cannot sign in to the Vendor app. Please use a vendor account.',
      );
    }
  }

  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // SIGN UP - VENDOR
  // ============================================================

  Future<AuthResponse> signUp({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'name': name.trim(), 'role': 'vendor', 'phone': phone.trim()},
    );
  }

  // ============================================================
  // SIGN IN
  // ============================================================

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

  // ============================================================
  // CURRENT AUTH USER
  // ============================================================

  User? get currentUser {
    return _supabase.auth.currentUser;
  }

  // ============================================================
  // CURRENT SESSION
  // ============================================================

  Session? get currentSession {
    return _supabase.auth.currentSession;
  }

  // ============================================================
  // AUTHENTICATED?
  // ============================================================

  bool get isAuthenticated {
    return _supabase.auth.currentSession != null;
  }

  // ============================================================
  // GET CURRENT USER FROM public.users
  // ============================================================

  Future<AuthModel?> getAuthUser() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return null;
    }

    final data = await _supabase
        .from('users')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) {
      return null;
    }

    return AuthModel.fromMap(data);
  }

  // ============================================================
  // SIGN OUT
  // ============================================================

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // ============================================================
  // AUTH STATE CHANGES
  // ============================================================

  Stream<AuthState> get authStateChanges {
    return _supabase.auth.onAuthStateChange;
  }
}
