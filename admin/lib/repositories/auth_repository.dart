import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/auth_model.dart';

class AuthRepository {
  final SupabaseClient _db;
  AuthRepository({SupabaseClient? client})
    : _db = client ?? Supabase.instance.client;
  User? get currentUser => _db.auth.currentUser;
  Session? get currentSession => _db.auth.currentSession;
  bool get isAuthenticated => currentSession != null;
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) {
      throw StateError('Enter email and password.');
    }
    final response = await _db.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    try {
      final profile = await _db.rpc('admin_context');
      if (profile == null) {
        throw StateError('This account has no active admin access.');
      }
    } catch (_) {
      await _db.auth.signOut();
      rethrow;
    }
    return response;
  }

  Future<AuthResponse> signUp({
    required String name,
    required String email,
    required String password,
  }) async => throw StateError(
    'Admin accounts are provisioned by an owner. Public admin signup is disabled.',
  );
  Future<AuthModel?> getAuthUser() async {
    final profile = await _db.rpc('admin_context');
    return profile == null
        ? null
        : AuthModel.fromMap(Map<String, dynamic>.from(profile as Map));
  }

  Future<void> signOut() => _db.auth.signOut();
}
