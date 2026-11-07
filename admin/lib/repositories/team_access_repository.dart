import 'package:supabase_flutter/supabase_flutter.dart';

class TeamAccessRepository {
  final SupabaseClient db;
  TeamAccessRepository({SupabaseClient? client})
    : db = client ?? Supabase.instance.client;
  Future<Map<String, dynamic>> workspace() async =>
      Map<String, dynamic>.from(await db.rpc('admin_team_workspace') as Map);
  Future<String> invite(
    Map<String, dynamic> values, {
    bool resend = false,
  }) async {
    final result = await db.functions.invoke(
      'admin-team-invite',
      body: {...values, 'resend': resend},
    );
    final data = Map<String, dynamic>.from(result.data as Map);
    if (data['error'] != null) throw StateError(data['error'].toString());
    return data['message']?.toString() ?? 'Invitation updated.';
  }

  Future<void> update(
    Map<String, dynamic> member,
    Map<String, dynamic> values,
  ) => db.rpc(
    'admin_team_update',
    params: {
      'p_id': member['id'],
      'p_revision': member['revision'],
      'p_name': values['name'],
      'p_level': values['level'],
      'p_active': values['active'],
      'p_permissions': values['permissions'],
    },
  );
  Future<void> revoke(String id) =>
      db.rpc('admin_team_revoke', params: {'p_id': id});
  Future<void> saveEmail(Map<String, String> values) => db.rpc(
    'admin_company_email_save',
    params: {
      'p_name': values['sender_name'],
      'p_email': values['sender_email'],
      'p_reply_to': values['reply_to'],
      'p_provider': values['provider'],
    },
  );
}
