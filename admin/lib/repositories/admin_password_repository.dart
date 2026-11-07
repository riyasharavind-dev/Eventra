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
    await db.auth.updateUser(UserAttributes(password: password));
    if (invitation) await db.rpc('admin_team_accept_invite');
  }

  Future<void> signOut() => db.auth.signOut();
}
