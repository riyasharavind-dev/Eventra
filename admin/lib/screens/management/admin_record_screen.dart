import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/admin_module.dart';
import '../../repositories/admin_repository.dart';
import '../../widgets/admin_management_helpers.dart';
import 'admin_record_editor.dart';
import 'admin_module_screen.dart';

class AdminRecordScreen extends StatefulWidget {
  final AdminRepository repo;
  final AdminModule module;
  final List<AdminModule> modules;
  final String id;
  final bool canWrite, isOwner;
  const AdminRecordScreen({
    super.key,
    required this.repo,
    required this.module,
    required this.modules,
    required this.id,
    this.canWrite = true,
    this.isOwner = false,
  });
  @override
  State<AdminRecordScreen> createState() => _AdminRecordScreenState();
}

class _AdminRecordScreenState extends State<AdminRecordScreen> {
  AdminRecord? row;
  bool loading = true, busy = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final record = await widget.repo.record(widget.module, widget.id);
      if (mounted) {
        setState(() {
          row = record;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          loading = false;
        });
      }
    }
  }

  Future<void> edit() async {
    final saved = await Navigator.push<AdminRecord>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminRecordEditor(
          repo: widget.repo,
          module: widget.module,
          modules: widget.modules,
          record: row,
        ),
      ),
    );
    if (saved != null && mounted) {
      await load();
    }
  }

  Future<void> deleteRecord() async {
    if (row == null || busy) return;
    final form = GlobalKey<FormState>();
    String reason = '', confirmation = '';
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this record?'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This permanently removes “${row!.title}”. Linked records prevent deletion. Uploaded files are retained for separate review.',
                  ),
                  const SizedBox(height: 16),
                  SelectableText('Record ID: ${widget.id}'),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Reason'),
                    onChanged: (v) => reason = v,
                    validator: (v) => (v?.trim().length ?? 0) < 5
                        ? 'Enter a reason (at least 5 characters)'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Type the exact record ID',
                    ),
                    onChanged: (v) => confirmation = v,
                    validator: (v) => v?.trim() == widget.id
                        ? null
                        : 'Record ID does not match',
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(c, true);
            },
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => busy = true);
    try {
      await widget.repo.deleteRecord(
        widget.module,
        row!,
        reason.trim(),
        confirmation.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) adminError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openRelated(String module, Map<String, dynamic> filters) async {
    final target = widget.modules.where((m) => m.name == module).firstOrNull;
    if (target == null) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(target.label)),
          body: AdminModuleScreen(
            repo: widget.repo,
            module: target,
            modules: widget.modules,
            filters: filters,
            canWrite: widget.canWrite && target.permittedWrite != false,
            isOwner: widget.isOwner,
          ),
        ),
      ),
    );
    if (mounted) {
      await load();
    }
  }

  Future<void> relation(String field) async {
    final relation = (row!.values['_relations'] as Map?)?[field];
    if (relation is! Map) {
      return;
    }
    final target = widget.modules
        .where((m) => m.name == relation['table'])
        .firstOrNull;
    if (target == null) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AdminRecordScreen(
          repo: widget.repo,
          module: target,
          modules: widget.modules,
          id: relation['id'].toString(),
          canWrite: widget.canWrite,
          isOwner: widget.isOwner,
        ),
      ),
    );
  }

  Future<void> link(String value) async {
    try {
      final uri = Uri.tryParse(value);
      if (uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          !await launchUrl(uri)) {
        throw StateError('Unable to open this link.');
      }
    } catch (e) {
      if (mounted) {
        adminError(context, e);
      }
    }
  }

  Future<void> document() async {
    if (busy) {
      return;
    }
    final field = switch (widget.module.name) {
      'verification_documents' => 'storage_path',
      'business_verifications' => 'document_path',
      'support_tickets' => 'screenshot_path',
      _ => '',
    };
    final bucket = switch (widget.module.name) {
      'verification_documents' => 'vendor-verification-documents',
      'business_verifications' => 'business-documents',
      _ => 'support-attachments',
    };
    final path = row?.values[field]?.toString();
    if (path == null || path.isEmpty) {
      return;
    }
    setState(() => busy = true);
    try {
      final url = await widget.repo.signedFile(bucket, path);
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (c) => Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 1000,
              maxHeight: MediaQuery.sizeOf(c).height * 0.9,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Private attachment · temporary access'),
                      ),
                      TextButton(
                        onPressed: () => link(url),
                        child: const Text('Open file'),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(c),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: InteractiveViewer(
                    minScale: 0.3,
                    maxScale: 5,
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, e, s) => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Image preview unavailable. Use Open file to view this document.',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        adminError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<Map<String, dynamic>?> categories() async {
    final nodes = widget.modules.firstWhere((m) => m.name == 'category_nodes');
    final all = <AdminRecord>[];
    for (var offset = 0; ; offset += 100) {
      final page = await widget.repo.records(
        nodes.name,
        offset: offset,
        limit: 100,
      );
      all.addAll(page.rows);
      if (all.length >= page.total) {
        break;
      }
    }
    final assigned = await widget.repo.records(
      'business_category_nodes',
      filters: {'business_id': widget.id},
      limit: 100,
    );
    final roots = all.where((r) => r.values['parent_id'] == null).toList();
    String root(String id) {
      final seen = <String>{};
      while (seen.add(id)) {
        final r = all.where((r) => r.values['id'] == id).firstOrNull;
        if (r == null || r.values['parent_id'] == null) {
          return id;
        }
        id = r.values['parent_id'].toString();
      }
      return id;
    }

    final selected = assigned.rows
        .map((r) => root(r.values['category_node_id'].toString()))
        .toSet();
    String? primary = row!.values['primary_category_id']?.toString();
    if (primary != null) {
      primary = root(primary);
    }
    if (!selected.contains(primary)) {
      primary = selected.firstOrNull;
    }
    if (!mounted) {
      return null;
    }
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialog) => AlertDialog(
          title: const Text('Business parent categories'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...roots.map(
                    (r) => CheckboxListTile(
                      title: Text(r.title),
                      value: selected.contains(r.id(nodes)),
                      onChanged: (v) => setDialog(() {
                        if (v == true) {
                          selected.add(r.id(nodes));
                          primary ??= r.id(nodes);
                        } else {
                          selected.remove(r.id(nodes));
                          if (primary == r.id(nodes)) {
                            primary = selected.firstOrNull;
                          }
                        }
                      }),
                    ),
                  ),
                  if (selected.isNotEmpty)
                    DropdownButtonFormField<String>(
                      key: ValueKey(primary),
                      initialValue: primary,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Primary category',
                      ),
                      items: roots
                          .where((r) => selected.contains(r.id(nodes)))
                          .map(
                            (r) => DropdownMenuItem(
                              value: r.id(nodes),
                              child: Text(r.title),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => primary = v,
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected.isEmpty || primary == null
                  ? null
                  : () => Navigator.pop(c, {
                      'category_ids': selected.toList(),
                      'primary_category_id': primary,
                    }),
              child: const Text('Save categories'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> action(String name) async {
    if (busy || row == null) {
      return;
    }
    setState(() => busy = true);
    try {
      if (name == 'cleanup_completed') {
        await widget.repo.cleanup(widget.module, row!);
      } else {
        final values = name == 'categories'
            ? await categories()
            : await confirmAdminAction(context, name);
        if (values == null) {
          return;
        }
        final saved = await widget.repo.action(
          widget.module,
          row!,
          name,
          values: values,
        );
        if (name == 'new_version' && saved != null && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => AdminRecordScreen(
                repo: widget.repo,
                module: widget.module,
                modules: widget.modules,
                id: saved.id(widget.module),
                canWrite: widget.canWrite,
                isOwner: widget.isOwner,
              ),
            ),
          );
        }
        if (name == 'delete_account') {
          final cleanupModule = widget.modules
              .where((m) => m.name == 'admin_storage_cleanup')
              .firstOrNull;
          if (cleanupModule != null) {
            final jobs = await widget.repo.records(
              cleanupModule.name,
              filters: {'request_id': widget.id, 'status': 'pending'},
            );
            for (final job in jobs.rows) {
              try {
                await widget.repo.cleanup(cleanupModule, job);
              } catch (_) {
                if (mounted) {
                  adminError(
                    context,
                    'Account deleted. Some files remain queued in Storage Cleanup.',
                  );
                }
              }
            }
          }
        }
        if (saved == null) {
          if (mounted) {
            Navigator.pop(context);
          }
          return;
        }
      }
      if (mounted) {
        await load();
      }
    } catch (e) {
      if (mounted) {
        adminError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Map<String, Map<String, dynamic>> related() {
    final v = row!.values, id = widget.id;
    return switch (widget.module.name) {
      'vendors' => {
        'support_tickets': {'user_id': id},
        for (final m in [
          'businesses',
          'services',
          'bookings',
          'verification_documents',
          'vendor_verifications',
          'vendor_identity_verifications',
          'service_reviews',
        ])
          m: {'vendor_id': id},
      },
      'users' => {
        'support_tickets': {'user_id': id},
      },
      'customers' => {
        'support_tickets': {'user_id': id},
        'bookings': {'customer_id': id},
        'service_reviews': {'customer_id': id},
      },
      'businesses' => {
        'business_category_nodes': {'business_id': id},
        'services': {'business_id': id, 'vendor_id': v['vendor_id']},
        'bookings': {'business_id': id},
        'business_verifications': {'business_id': id},
        'service_reviews': {'business_id': id},
      },
      'services' => {
        'bookings': {'service_id': id},
        'service_reviews': {'service_id': id},
      },
      'bookings' => {
        for (final m in [
          'booking_status_history',
          'booking_vendor_notes',
          'service_reviews',
        ])
          m: {'booking_id': id},
      },
      'published_about_eventra_content' => {
        'about_eventra_content': {'id': id},
      },
      'published_support_faqs' => {
        'support_faqs': {'id': id},
      },
      'active_social_links' => {
        'social_links': {'id': id},
      },
      'current_legal_documents' => {
        'legal_documents': {'id': id},
      },
      'support_tickets' => {
        'support_messages': {'ticket_id': id},
      },
      'service_reviews' => {
        'service_review_reports': {'review_id': id},
      },
      _ => {},
    };
  }

  Widget value(AdminField f) {
    final raw = row!.values[f.name];
    final reference = (row!.values['_relations'] as Map?)?[f.name];
    if (raw is Map || raw is List) {
      return SelectableText(
        const JsonEncoder.withIndent('  ').convert(raw),
        style: const TextStyle(fontSize: 12, height: 1.5),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SelectableText(
            f.name == 'status' && row!.values[f.name] == 'waiting_for_vendor'
                ? 'Awaiting requester reply'
                : row!.display(f.name),
          ),
        ),
        if (reference is Map)
          IconButton(
            tooltip: 'Open linked record',
            onPressed: () => relation(f.name),
            icon: const Icon(Icons.open_in_new, size: 18),
          ),
        if (raw is String && raw.startsWith('https://'))
          IconButton(
            tooltip: 'Open link',
            onPressed: () => link(raw),
            icon: const Icon(Icons.link, size: 18),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final published =
        widget.module.name == 'legal_documents' &&
        row?.values['published_at'] != null;
    final fileField = switch (widget.module.name) {
      'verification_documents' => 'storage_path',
      'business_verifications' => 'document_path',
      'support_tickets' => 'screenshot_path',
      _ => '',
    };
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(row?.title ?? widget.module.label),
          actions: [
            IconButton(
              tooltip: 'Reload',
              onPressed: busy ? null : load,
              icon: const Icon(Icons.refresh),
            ),
            if (widget.isOwner &&
                widget.canWrite &&
                widget.module.canDelete &&
                !published)
              IconButton(
                tooltip: 'Delete record',
                onPressed: busy || row == null ? null : deleteRecord,
                icon: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            if (widget.canWrite &&
                widget.module.editable.isNotEmpty &&
                !published)
              IconButton(
                tooltip: 'Edit record',
                onPressed: busy || row == null ? null : edit,
                icon: const Icon(Icons.edit_outlined),
              ),
          ],
        ),
        body: loading && row == null
            ? const Center(child: CircularProgressIndicator())
            : row == null
            ? Center(
                child: TextButton(
                  onPressed: load,
                  child: const Text('Unable to load. Retry'),
                ),
              )
            : AbsorbPointer(
                absorbing: busy,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (busy || loading) const LinearProgressIndicator(),
                    if (error != null)
                      TextButton(
                        onPressed: load,
                        child: const Text(
                          'Refresh failed. Retry before making changes.',
                        ),
                      ),
                    if (widget.module.name == 'users')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            row!.values['_account_suspended'] == true
                                ? Icons.block
                                : Icons.verified_user_outlined,
                          ),
                          title: Text(
                            row!.values['_managed_admin'] == true
                                ? 'Admin account · Manage in Team & Access'
                                : row!.values['_account_suspended'] == true
                                ? 'Account suspended'
                                : 'Account active',
                          ),
                        ),
                      ),
                    if (widget.canWrite)
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children:
                            availableAdminActions(
                                  widget.module,
                                  row!,
                                  owner: widget.isOwner,
                                )
                                .map(
                                  (a) => OutlinedButton.icon(
                                    onPressed: () => action(a),
                                    icon: Icon(
                                      a == 'delete_account'
                                          ? Icons.delete_forever
                                          : Icons.check_circle_outline,
                                    ),
                                    label: Text(adminActionLabel(a)),
                                  ),
                                )
                                .toList(),
                      ),
                    if (row!.values[fileField] != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: FilledButton.icon(
                          onPressed: document,
                          icon: const Icon(Icons.description_outlined),
                          label: const Text('View private attachment'),
                        ),
                      ),
                    if (published)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Published legal history is read only. Use Create new draft version to update it.',
                        ),
                      ),
                    if (widget.module.name == 'support_tickets' &&
                        row!.values['user_id'] != null)
                      _SupportRequester(
                        key: ValueKey(row!.values['user_id']),
                        repo: widget.repo,
                        modules: widget.modules,
                        userId: row!.values['user_id'].toString(),
                      ),
                    const SizedBox(height: 16),
                    ...widget.module.fields.map(
                      (f) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 7),
                              value(f),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (widget.module.name == 'support_tickets')
                      _Conversation(
                        repo: widget.repo,
                        ticketId: widget.id,
                        refresh: row!.revision,
                      ),
                    if (related().isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Related records',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      ...related().entries.map((e) {
                        final target = widget.modules
                            .where((m) => m.name == e.key)
                            .firstOrNull;
                        return target == null
                            ? const SizedBox.shrink()
                            : Card(
                                child: ListTile(
                                  title: Text(target.label),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => openRelated(e.key, e.value),
                                ),
                              );
                      }),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _Conversation extends StatefulWidget {
  final AdminRepository repo;
  final String ticketId, refresh;
  const _Conversation({
    required this.repo,
    required this.ticketId,
    required this.refresh,
  });
  @override
  State<_Conversation> createState() => _ConversationState();
}

class _ConversationState extends State<_Conversation> {
  late Future<AdminPage> messages;
  @override
  void initState() {
    super.initState();
    messages = fetch();
  }

  Future<AdminPage> fetch() => widget.repo.records(
    'support_messages',
    filters: {'ticket_id': widget.ticketId},
    limit: 100,
  );
  @override
  void didUpdateWidget(covariant _Conversation old) {
    super.didUpdateWidget(old);
    if (old.refresh != widget.refresh) {
      messages = fetch();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AdminPage>(
    future: messages,
    builder: (c, s) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Conversation · latest 100 messages',
          style: Theme.of(c).textTheme.titleLarge,
        ),
        if (s.connectionState != ConnectionState.done)
          const LinearProgressIndicator(),
        if (s.hasError)
          TextButton(
            onPressed: () {
              setState(() {
                messages = fetch();
              });
            },
            child: const Text('Retry conversation'),
          ),
        for (final m in s.data?.rows.reversed ?? <AdminRecord>[])
          Card(
            color: m.values['sender_role'] == 'support'
                ? Theme.of(c).colorScheme.primaryContainer
                : null,
            child: ListTile(
              title: Text(m.values['body'].toString()),
              subtitle: Text(
                '${m.values['sender_role']} · ${m.values['created_at']}',
              ),
            ),
          ),
      ],
    ),
  );
}

class _SupportRequester extends StatefulWidget {
  const _SupportRequester({
    super.key,
    required this.repo,
    required this.modules,
    required this.userId,
  });
  final AdminRepository repo;
  final List<AdminModule> modules;
  final String userId;
  @override
  State<_SupportRequester> createState() => _SupportRequesterState();
}

class _SupportRequesterState extends State<_SupportRequester> {
  Future<AdminRecord>? _requester;
  @override
  void initState() {
    super.initState();
    final users = widget.modules.where((m) => m.name == 'users').firstOrNull;
    if (users != null) _requester = widget.repo.record(users, widget.userId);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AdminRecord>(
    future: _requester,
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox.shrink();
      final requester = snapshot.data!;
      final role = requester.values['role']?.toString() ?? 'Account';
      return Card(
        child: ListTile(
          leading: Icon(
            role == 'customer'
                ? Icons.person_outline
                : Icons.storefront_outlined,
          ),
          title: Text('${adminLabel(role)} support request'),
          subtitle: Text(
            '${requester.title}\n${requester.values['email'] ?? ''}',
          ),
        ),
      );
    },
  );
}
