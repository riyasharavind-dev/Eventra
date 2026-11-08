import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account_security_model.dart';

class AccountSecurityRepository {
  AccountSecurityRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  Future<AccountSecurityModel> load() async {
    await _client.auth.getUser();
    final data = await _client.rpc('get_customer_account_security');
    return AccountSecurityModel.fromMap(Map<String, dynamic>.from(data as Map));
  }

  Future<void> _confirmPassword(String password) async {
    final user = (await _client.auth.getUser()).user;
    if (user == null || user.email == null) {
      throw Exception('Please log in again.');
    }
    final response = await _client.auth.signInWithPassword(
      email: user.email!,
      password: password,
    );
    if (response.user?.id != user.id) {
      throw Exception('Unable to verify your account.');
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    String? nonce,
  }) async {
    await _confirmPassword(currentPassword);
    await _client.auth.updateUser(
      UserAttributes(
        password: newPassword,
        currentPassword: currentPassword,
        nonce: nonce?.trim().isEmpty == true ? null : nonce?.trim(),
      ),
    );
  }

  Future<void> sendPasswordCode() => _client.auth.reauthenticate();

  Future<void> changeEmail({
    required String currentPassword,
    required String email,
  }) async {
    await _confirmPassword(currentPassword);
    await _client.auth.updateUser(UserAttributes(email: email.trim()));
  }

  Future<void> updatePhone(String phone) async {
    await _client.rpc(
      'update_customer_contact_phone',
      params: {'p_phone': phone.trim()},
    );
  }

  Future<void> requestDeletion({
    required String password,
    required String reason,
  }) async {
    await _confirmPassword(password);
    await _client.rpc(
      'request_customer_account_deletion',
      params: {'p_reason': reason.trim()},
    );
  }

  Future<void> cancelDeletion() async {
    await _client.rpc('cancel_customer_account_deletion');
  }
}
