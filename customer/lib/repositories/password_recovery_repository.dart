import 'package:supabase_flutter/supabase_flutter.dart';

class PasswordRecoveryRepository {
  PasswordRecoveryRepository({this.client});
  final SupabaseClient? client;
  SupabaseClient get _db => client ?? Supabase.instance.client;
  Future<void> request(String email) => _db.auth.resetPasswordForEmail(email);
  Future<void> verify(String email, String code) async {
    await _db.auth.verifyOTP(email: email, token: code, type: OtpType.recovery);
  }

  Future<void> save(String password) async {
    await _db.auth.updateUser(UserAttributes(password: password));
    await _db.auth.signOut(scope: SignOutScope.local);
  }
}
