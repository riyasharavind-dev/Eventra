import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';

class AdminPasswordRepository {
  final SupabaseClient db;
  late final String? initialUserId;
  AdminPasswordRepository({SupabaseClient? client})
    : db = client ?? Supabase.instance.client {
    initialUserId = db.auth.currentUser?.id;
  }

  bool get needsMfa {
    final assurance = db.auth.mfa.getAuthenticatorAssuranceLevel();
    return assurance.nextLevel == AuthenticatorAssuranceLevels.aal2 &&
        assurance.currentLevel != AuthenticatorAssuranceLevels.aal2;
  }

  Future<void> requestReset(String email) async {
    // Recovery emails must also work when opened in a different browser/device.
    // This isolated sender creates a one-time email link without a browser-bound
    // PKCE verifier. Normal admin sign-in retains its existing PKCE configuration.
    final sender = GoTrueClient(
      url: '${SupabaseConfig.url}/auth/v1',
      headers: {'apikey': SupabaseConfig.anonKey},
      flowType: AuthFlowType.implicit,
      autoRefreshToken: false,
    );
    try {
      await sender.resetPasswordForEmail(
        email.trim(),
        redirectTo: 'https://eventor-admin.onrender.com/?auth_action=recovery',
      );
    } finally {
      sender.dispose();
    }
  }

  Future<void> savePassword(
    String password, {
    String? code,
    bool invitation = false,
  }) async {
    if (db.auth.currentSession == null ||
        initialUserId == null ||
        db.auth.currentUser?.id != initialUserId) {
      throw StateError('This link has expired. Request a new reset email.');
    }
    if (needsMfa) {
      if (!RegExp(r'^\d{6}$').hasMatch(code ?? '')) {
        throw StateError('Enter the six-digit code from your authenticator.');
      }
      final factors = await db.auth.mfa.listFactors();
      if (factors.totp.isEmpty) {
        throw StateError(
          'Your authenticator could not be found. Contact your owner for recovery.',
        );
      }
      await db.auth.mfa.challengeAndVerify(
        factorId: factors.totp.first.id,
        code: code!,
      );
    }
    final email = db.auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      throw StateError('No email is associated with this recovery session.');
    }
    final updated = await db.auth.updateUser(
      UserAttributes(password: password),
    );
    if (updated.user?.id != initialUserId) {
      throw StateError('Could not confirm which account was updated.');
    }

    // A recovery session alone does not prove the new password works.
    // Verify with a separate client so the current MFA session stays intact.
    final verifier = GoTrueClient(
      url: '${SupabaseConfig.url}/auth/v1',
      headers: {'apikey': SupabaseConfig.anonKey},
      autoRefreshToken: false,
    );
    try {
      final result = await verifier.signInWithPassword(
        email: email,
        password: password,
      );
      if (result.session == null || result.user?.id != initialUserId) {
        throw StateError('Could not verify sign-in for the updated account.');
      }
    } finally {
      try {
        if (verifier.currentSession != null) {
          await verifier.signOut(scope: SignOutScope.local);
        }
      } finally {
        verifier.dispose();
      }
    }
    if (invitation) await db.rpc('admin_team_accept_invite');
  }

  Future<void> signOut() => db.auth.signOut(scope: SignOutScope.local);
}
