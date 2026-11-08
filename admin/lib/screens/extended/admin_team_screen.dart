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
    if (values != null && mounted) {
      await run(() async {
        await repo.saveEmail(values);
        return 'Sender preferences saved. SMTP verification is still required in Supabase before emails can be sent.';
      });
    }
  }

  Future<void> revoke(Map<String, dynamic> invite) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Revoke invitation?'),
        content: Text(
          '${invite['email']} will not be able to activate this invitation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await run(() async {
        await repo.revoke(invite['id'] as String);
        return null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data == null && error == null) {
      return const Center(child: CircularProgressIndicator());
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
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Invite Staff'),
            ),
            OutlinedButton.icon(
              onPressed: busy || data == null ? null : emailSettings,
              icon: const Icon(Icons.alternate_email),
              label: const Text('Company Email Settings'),
            ),
            TextButton(
              onPressed: busy ? null : load,
              child: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Staff use their own work email and set their own password. Company mailboxes must be created with your email provider. Sender preferences do not configure or verify SMTP.',
            ),
          ),
        ),
        if (busy) const LinearProgressIndicator(),
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
        Text('Team Members', style: Theme.of(context).textTheme.titleLarge),
        for (final raw in members)
          Builder(
            builder: (context) {
              final m = Map<String, dynamic>.from(raw as Map);
              return Card(
                child: ListTile(
                  isThreeLine: true,
                  leading: const Icon(Icons.person_outline),
                  title: Text('${m['name']} · ${m['access_level']}'),
                  subtitle: Text(
                    '${m['email']}\n${m['is_active'] == true ? 'Active' : 'Suspended'} · Last login: ${m['last_login'] ?? 'Never'}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Edit role, permissions and status',
                    onPressed: busy ? null : () => edit(member: m),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 24),
        Text('Invitations', style: Theme.of(context).textTheme.titleLarge),
        if (invites.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No pending invitations.'),
          ),
        for (final raw in invites)
          Builder(
            builder: (context) {
              final i = Map<String, dynamic>.from(raw as Map),
                  expired =
                      DateTime.tryParse(raw['expires_at'].toString())
                          ?.isBefore(DateTime.now()) ??
                      true;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${i['name']} · ${i['email']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${i['access_level']} · ${i['status'] == 'revoked'
                            ? 'Revoked'
                            : expired
                            ? 'Expired'
                            : 'Pending'}${i['delivery_error'] == true ? ' · Email setup/delivery needs attention' : ''}',
                      ),
                      Text('Expires: ${i['expires_at']}'),
                      Wrap(
                        spacing: 12,
                        children: [
                          TextButton(
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
                            child: const Text('Resend invitation'),
                          ),
                          if (i['status'] == 'pending')
                            TextButton(
                              onPressed: busy ? null : () => revoke(i),
                              child: const Text('Revoke'),
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
        Text(
          'Recent Team Activity',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        for (final a in data?['activity'] as List? ?? [])
          ListTile(
            title: Text(a['action'].toString().replaceAll('_', ' ')),
            subtitle: Text(
              '${a['created_at']} · Actor: ${a['actor_id'] ?? 'System'}',
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
              if (widget.member != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active access'),
                  subtitle: const Text(
                    'Switch off to suspend this member immediately.',
                  ),
                  value: active,
                  onChanged: (v) => setState(() => active = v),
                ),
              if (level == 'owner' || level == 'admin')
                Text(
                  level == 'owner'
                      ? 'Full access, including Team & Access and infrastructure.'
                      : 'All operational modules. Team, credentials, audit and infrastructure remain owner-only.',
                )
              else ...[
                const SizedBox(height: 16),
                const Text(
                  'Choose allowed modules. View is required before Edit.',
                ),
                for (final m in widget.modules)
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(m['label'].toString()),
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
                            const Text('Edit'),
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
    title: const Text('Company Email Settings'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Save your preferred sender details here. An owner must also configure matching sender/domain and SMTP credentials in Supabase Auth. Never enter SMTP passwords here. This does not create company mailboxes.',
              ),
              for (final entry in {
                'sender_name': 'Sender name',
                'sender_email': 'Sender email',
                'reply_to': 'Reply-to email',
                'provider': 'Email provider name',
              }.entries)
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
