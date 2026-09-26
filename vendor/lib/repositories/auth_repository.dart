import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/auth_model.dart';

class AuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // -----------------------------
  // SIGN UP - VENDOR
  // -----------------------------

  Future<AuthResponse> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'name': name.trim(),
        'role': 'vendor',
      },
    );
  }

  // -----------------------------
  // SIGN IN
  // -----------------------------

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  // -----------------------------
  // GET CURRENT AUTH USER
  // -----------------------------

  User? get currentUser {
    return _supabase.auth.currentUser;
  }

  // -----------------------------
  // GET CURRENT SESSION
  // -----------------------------

  Session? get currentSession {
    return _supabase.auth.currentSession;
  }

  // -----------------------------
  // CHECK AUTHENTICATION
  // -----------------------------

  bool get isAuthenticated {
    return _supabase.auth.currentSession != null;
  }

  // -----------------------------
  // GET USER FROM public.users
  // -----------------------------

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

  // -----------------------------
  // SIGN OUT
  // -----------------------------

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // -----------------------------
  // AUTH STATE CHANGES
  // -----------------------------

  Stream<AuthState> get authStateChanges {
    return _supabase.auth.onAuthStateChange;
  }
}