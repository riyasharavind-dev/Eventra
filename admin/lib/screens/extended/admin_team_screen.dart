import '../../services/app_live_data.dart';

import 'package:flutter/material.dart';

import '../../repositories/team_access_repository.dart';

class AdminTeamScreen extends StatefulWidget {
  final TeamAccessRepository? repository;
  const AdminTeamScreen({super.key, this.repository});
  @override
  State<AdminTeamScreen> createState() => _AdminTeamScreenState();
}

class _AdminTeamScreenState extends State<AdminTeamScreen>
    with LiveDataState<AdminTeamScreen> {
  @override
  Set<String> get liveDatasets => {
    'admin:admins',
    'admin:team_permissions',
    'own:team_permissions',
    'admin:module_permissions',
    'admin:team_invitations',
    'admin:company_email_settings',
  };

  @override
  Future<void> onLiveData(Set<String> changed) async {
    await load();
  }

  late final repo = widget.repository ?? TeamAccessRepository();
  Map<String, dynamic>? data;
  String? error, message;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await repo.workspace();
      if (mounted) {
        setState(() {
          data = result;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> run(Future<String?> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      final result = await action();
      if (mounted) setState(() => message = result ?? 'Changes saved.');
      await load();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit({Map<String, dynamic>? member}) async {
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _MemberDialog(
        member: member,
        modules: List<Map<String, dynamic>>.from(
          (data?['modules'] as List? ?? []).map(
            (e) => Map<String, dynamic>.from(e as Map),
          ),
        ),
      ),
    );
    if (values == null || !mounted) return;
    await run(() async {
      if (member == null) return repo.invite(values);
      await repo.update(member, values);
      return null;
    });
  }

  Future<void> emailSettings() async {
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _EmailDialog(
        values: Map<String, dynamic>.from(
          data?['email_settings'] as Map? ?? {},
        ),
      ),
    );
    if (values == null || !mounted) return;
    await run(() async {
      await repo.saveEmail(values);
      return 'Email preferences saved.';
    });
  }

  Future<void> revoke(Map<String, dynamic> invite) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Revoke invitation?'),
        content: Text('Cancel the invitation for “${invite['name']}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await run(() async {
        await repo.revoke(invite['id'] as String);
        return null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data == null && error == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF80152C)),
      );
    }
    final members = data?['members'] as List? ?? [],
        invites = data?['invitations'] as List? ?? [];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: busy || data == null ? null : () => edit(),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Invite Staff'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: busy || data == null ? null : emailSettings,
              icon: const Icon(Icons.alternate_email, size: 18),
              label: const Text('Company Email Settings'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: busy ? null : load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF0EDF0)),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF80152C),
                size: 20,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Staff use their own work email and set their own password. Company mailboxes must be created with your email provider. Sender preferences do not configure or verify SMTP.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF73737D),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(color: Color(0xFF80152C)),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (message != null)
          Padding(padding: const EdgeInsets.all(12), child: Text(message!)),
        const SizedBox(height: 20),
        const Text(
          'Team Members',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF17171B),
          ),
        ),
        const SizedBox(height: 12),
        for (final raw in members)
          Builder(
            builder: (context) {
              final m = Map<String, dynamic>.from(raw as Map);
              final role = (m['access_level']?.toString() ?? 'staff')
                  .toUpperCase();
              final isActive = m['is_active'] == true;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF0EDF0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF80152C).withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFF5E8EC),
                        child: Text(
                          ((m['name'] as String?)?.isNotEmpty == true)
                              ? (m['name'] as String)
                                    .substring(0, 1)
                                    .toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Color(0xFF80152C),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  m['name']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF17171B),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: role == 'OWNER'
                                        ? const Color(0xFFFFF8E1)
                                        : const Color(0xFFF5E8EC),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    role,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: role == 'OWNER'
                                          ? const Color(0xFFB8860B)
                                          : const Color(0xFF80152C),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? const Color(0xFFE8F5E9)
                                        : const Color(0xFFFFEBEE),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isActive ? 'ACTIVE' : 'SUSPENDED',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isActive
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFC62828),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${m['email']} · Last login: ${m['last_login'] ?? 'Never'}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF73737D),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit role & permissions',
                        onPressed: busy ? null : () => edit(member: m),
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: Color(0xFF73737D),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 24),
        const Text(
          'Invitations',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF17171B),
          ),
        ),
        const SizedBox(height: 12),
        if (invites.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No pending invitations.',
              style: TextStyle(color: Color(0xFF73737D)),
            ),
          ),
        for (final raw in invites)
          Builder(
            builder: (context) {
              final i = Map<String, dynamic>.from(raw as Map),
                  expired =
                      DateTime.tryParse(raw['expires_at'].toString())
                          ?.isBefore(DateTime.now()) ??
                      true;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF0EDF0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${i['name']} · ${i['email']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5E8EC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              (i['status'] == 'revoked'
                                      ? 'Revoked'
                                      : expired
                                      ? 'Expired'
                                      : 'Pending')
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF80152C),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Role: ${(i['access_level']?.toString() ?? 'staff').toUpperCase()} · Expires: ${i['expires_at']}${i['delivery_error'] == true ? ' · Email setup/delivery needs attention' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF73737D),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                            ),
                            onPressed: busy
                                ? null
                                : () => run(
                                    () => repo.invite({
                                      'email': i['email'],
                                      'name': i['name'],
                                      'level': i['access_level'],
                                      'permissions': i['permissions'],
                                    }, resend: true),
                                  ),
                            icon: const Icon(Icons.send_rounded, size: 16),
                            label: const Text('Resend invitation'),
                          ),
                          if (i['status'] == 'pending')
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFC62828),
                              ),
                              onPressed: busy ? null : () => revoke(i),
                              icon: const Icon(Icons.cancel_outlined, size: 16),
                              label: const Text('Revoke'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 24),
        const Text(
          'Recent Team Activity',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF17171B),
          ),
        ),
        const SizedBox(height: 12),
        for (final a in data?['activity'] as List? ?? [])
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF0EDF0)),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                leading: const Icon(
                  Icons.history_rounded,
                  color: Color(0xFF80152C),
                ),
                title: Text(
                  a['action'].toString().replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  '${a['created_at']} · Actor: ${a['actor_id'] ?? 'System'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF73737D),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MemberDialog extends StatefulWidget {
  final Map<String, dynamic>? member;
  final List<Map<String, dynamic>> modules;
  const _MemberDialog({this.member, required this.modules});
  @override
  State<_MemberDialog> createState() => _MemberDialogState();
}

class _MemberDialogState extends State<_MemberDialog> {
  final form = GlobalKey<FormState>();
  late String name = widget.member?['name']?.toString() ?? '',
      email = widget.member?['email']?.toString() ?? '',
      level = widget.member?['access_level']?.toString() ?? 'staff';
  late bool active = widget.member?['is_active'] == true;
  late Map<String, dynamic> permissions = Map<String, dynamic>.from(
    widget.member?['permissions'] as Map? ?? {},
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Text(widget.member == null ? 'Invite Staff' : 'Edit Team Access'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: name,
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: (v) => name = v,
                validator: (v) =>
                    v == null || v.trim().isEmpty || v.trim().length > 100
                    ? 'Enter a name (1–100 characters)'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: email,
                enabled: widget.member == null,
                decoration: const InputDecoration(labelText: 'Work email'),
                keyboardType: TextInputType.emailAddress,
                onChanged: (v) => email = v,
                validator: (v) =>
                    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                        .hasMatch(v?.trim() ?? '')
                    ? null
                    : 'Enter a valid email',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: level,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const ['owner', 'admin', 'staff', 'viewer']
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(v.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => level = v!),
              ),
              if (widget.member != null) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active access'),
                  subtitle: const Text(
                    'Switch off to suspend this member immediately.',
                  ),
                  value: active,
                  onChanged: (v) => setState(() => active = v),
                ),
              ],
              const SizedBox(height: 14),
              if (level == 'owner' || level == 'admin')
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    level == 'owner'
                        ? 'Full access, including Team & Access and platform infrastructure.'
                        : 'All operational modules. Team, credentials, audit and infrastructure remain owner-only.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF73737D),
                    ),
                  ),
                )
              else ...[
                const SizedBox(height: 12),
                const Text(
                  'Choose allowed modules. View is required before Edit.',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                for (final m in widget.modules)
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            m['label'].toString(),
                            style: const TextStyle(fontSize: 13),
                          ),
                          value: permissions.containsKey(m['name']),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              permissions[m['name'].toString()] = false;
                            } else {
                              permissions.remove(m['name']);
                            }
                          }),
                        ),
                      ),
                      if (level == 'staff')
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Edit', style: TextStyle(fontSize: 12)),
                            Checkbox(
                              value: permissions[m['name']] == true,
                              onChanged: !permissions.containsKey(m['name'])
                                  ? null
                                  : (v) => setState(
                                      () => permissions[m['name'].toString()] =
                                          v == true,
                                    ),
                            ),
                          ],
                        ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, {
              'name': name.trim(),
              'email': email.trim().toLowerCase(),
              'level': level,
              'active': active,
              'permissions': level == 'viewer'
                  ? permissions.map((k, v) => MapEntry(k, false))
                  : permissions,
            });
          }
        },
        child: Text(widget.member == null ? 'Send Invitation' : 'Save'),
      ),
    ],
  );
}

class _EmailDialog extends StatefulWidget {
  final Map<String, dynamic> values;
  const _EmailDialog({required this.values});
  @override
  State<_EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends State<_EmailDialog> {
  final form = GlobalKey<FormState>();
  late final values = {
    for (final k in ['sender_name', 'sender_email', 'reply_to', 'provider'])
      k: widget.values[k]?.toString() ?? '',
  };
  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: const Text('Company Email Settings'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8FA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Save your preferred sender details here. An owner must also configure matching sender/domain and SMTP credentials in Supabase Auth. Never enter SMTP passwords here.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF73737D)),
                ),
              ),
              const SizedBox(height: 14),
              for (final entry in {
                'sender_name': 'Sender name',
                'sender_email': 'Sender email',
                'reply_to': 'Reply-to email',
                'provider': 'Email provider name',
              }.entries) ...[
                TextFormField(
                  initialValue: values[entry.key],
                  decoration: InputDecoration(labelText: entry.value),
                  onChanged: (v) => values[entry.key] = v.trim(),
                  validator: (v) {
                    if (entry.key == 'sender_name' &&
                        (v == null || v.trim().isEmpty || v.length > 100)) {
                      return 'Enter a sender name (1–100 characters)';
                    }
                    if (entry.key.contains('email') ||
                        entry.key == 'reply_to') {
                      if (v != null &&
                          v.isNotEmpty &&
                          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) {
                        return 'Enter a valid email';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) Navigator.pop(context, values);
        },
        child: const Text('Save preferences'),
      ),
    ],
  );
}
