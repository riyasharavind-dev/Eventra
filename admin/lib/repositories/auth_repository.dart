import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/auth_model.dart';

class AuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // -----------------------------
  // SIGN UP
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
  // CURRENT USER
  // -----------------------------

  User? get currentUser {
    return _supabase.auth.currentUser;
  }

  // -----------------------------
  // CURRENT SESSION
  // -----------------------------

  Session? get currentSession {
    return _supabase.auth.currentSession;
  }

  // -----------------------------
  // AUTHENTICATED CHECK
  // -----------------------------

  bool get isAuthenticated {
    return _supabase.auth.currentSession != null;
  }

  // -----------------------------
  // GET AUTH USER PROFILE
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