import '../../services/app_live_data.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/admin_module.dart';
import '../../repositories/admin_repository.dart';
import '../../widgets/admin_event_categories.dart';
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

class _AdminRecordScreenState extends State<AdminRecordScreen>
    with LiveDataState<AdminRecordScreen> {
  @override
  bool get liveCanRefresh => !busy;
  @override
  Set<String> get liveDatasets => {
    'admin:${widget.module.name}',
    for (final f in widget.module.fields)
      if (f.referenceTable != null) 'admin:${f.referenceTable}',
    'admin:service_reviews',
    'admin:booking_status_history',
    'admin:support_messages',
  };
  @override
  Future<void> onLiveData(Set<String> changed) async {
    await load();
  }

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
      if (!liveRefreshing) loading = true;
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
    final saved = await showAdminRecordPanel<AdminRecord>(
      context,
      (_) => AdminRecordEditor(
        repo: widget.repo,
        module: widget.module,
        modules: widget.modules,
        record: row,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.delete_forever,
                color: Colors.red.shade700,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Flexible(child: Text('Delete record permanently?')),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will permanently remove “${row!.title}”. Linked records prevent deletion. Uploaded files are retained for separate review.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Record ID: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        Expanded(
                          child: SelectableText(
                            widget.id,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Reason',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (v) => reason = v,
                    validator: (v) => (v?.trim().length ?? 0) < 5
                        ? 'Enter a reason (at least 5 characters)'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Type the exact record ID',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 1000,
              maxHeight: MediaQuery.sizeOf(c).height * 0.9,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: Color(0xFF80152C),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Private Attachment · Temporary Signed Access',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => link(url),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Open External'),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => Navigator.pop(c),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: InteractiveViewer(
                    minScale: 0.3,
                    maxScale: 5,
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, e, s) => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Image preview unavailable. Use "Open External" to view this document.',
                          ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Manage Business Categories'),
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
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(primary),
                        initialValue: primary,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Primary category',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
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
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF80152C),
              ),
              onPressed: selected.isEmpty || primary == null
                  ? null
                  : () => Navigator.pop(c, {
                      'category_ids': selected.toList(),
                      'primary_category_id': primary,
                    }),
              child: const Text('Save Categories'),
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
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SelectableText(
          const JsonEncoder.withIndent('  ').convert(raw),
          style: const TextStyle(
            fontSize: 12,
            height: 1.5,
            fontFamily: 'monospace',
          ),
        ),
      );
    }
    final isUrl = raw is String && raw.startsWith('https://');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: SelectableText(
            f.name == 'status' && row!.values[f.name] == 'waiting_for_vendor'
                ? 'Awaiting requester reply'
                : row!.display(f.name),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        if (reference is Map)
          Tooltip(
            message: 'Open linked record',
            child: InkWell(
              onTap: () => relation(f.name),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF80152C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.open_in_new, size: 13, color: Color(0xFF80152C)),
                  ],
                ),
              ),
            ),
          ),
        if (isUrl)
          IconButton(
            tooltip: 'Open link in browser',
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            onPressed: () => link(raw),
            icon: const Icon(Icons.link, color: Color(0xFF80152C)),
          ),
      ],
    );
  }

  /// Groups field display into clean, themed cards
  List<Widget> _buildGroupedFields(BuildContext context) {
    final fields = widget.module.fields;
    final contentFields = <AdminField>[];
    final mediaFields = <AdminField>[];
    final generalFields = <AdminField>[];

    for (final f in fields) {
      if (f.longText ||
          f.name == 'description' ||
          f.name == 'content_markdown') {
        contentFields.add(f);
      } else if (f.image ||
          f.name == 'gallery' ||
          f.name == 'portfolio' ||
          f.name.contains('image') ||
          f.name.contains('icon')) {
        mediaFields.add(f);
      } else {
        generalFields.add(f);
      }
    }

    Widget buildCard({
      required String title,
      required IconData icon,
      required List<AdminField> sectionFields,
    }) {
      if (sectionFields.isEmpty) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0EDF0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: const Color(0xFF80152C)),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF1F2024),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF5F5F7)),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sectionFields.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                color: Color(0xFFFAFAFA),
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (_, idx) {
                final f = sectionFields[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      value(f),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    return [
      buildCard(
        title: 'Record Attributes',
        icon: Icons.list_alt,
        sectionFields: generalFields,
      ),
      if (contentFields.isNotEmpty)
        buildCard(
          title: 'Content & Information',
          icon: Icons.article_outlined,
          sectionFields: contentFields,
        ),
      if (mediaFields.isNotEmpty)
        buildCard(
          title: 'Visual Assets & Media',
          icon: Icons.photo_library_outlined,
          sectionFields: mediaFields,
        ),
    ];
  }

  /// Builds the right-hand action and metadata sidebar
  Widget _buildSidebar(BuildContext context, bool published, String fileField) {
    final actions = availableAdminActions(
      widget.module,
      row!,
      owner: widget.isOwner,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Quick Status & Control Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF0EDF0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt, size: 18, color: Color(0xFF80152C)),
                  SizedBox(width: 8),
                  Text(
                    'Control & Actions',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Record ID row with 1-tap copy
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9FB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEFEFF2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.fingerprint, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.id,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: Color(0xFF444444),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy ID',
                      iconSize: 14,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: widget.id));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Record ID copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Edit Record Button
              if (widget.canWrite &&
                  widget.module.editable.isNotEmpty &&
                  !published)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: busy ? null : edit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF80152C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit Record Details'),
                    ),
                  ),
                ),

              // Private Attachment Button
              if (row!.values[fileField] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: document,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text('View Private Attachment'),
                    ),
                  ),
                ),

              // Specific module actions
              if (widget.canWrite && actions.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: Color(0xFFF0EDF0)),
                ),
                Text(
                  'AVAILABLE OPERATIONS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                ...actions.map((a) {
                  final isDestructive =
                      a == 'delete_account' ||
                      a == 'suspend_account' ||
                      a == 'rejected' ||
                      a == 'failed';
                  final isPositive =
                      a == 'verify' ||
                      a == 'approved' ||
                      a == 'accepted' ||
                      a == 'completed' ||
                      a == 'publish';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => action(a),
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          foregroundColor: isDestructive
                              ? Colors.red.shade700
                              : isPositive
                              ? const Color(0xFF1B6E3E)
                              : const Color(0xFF1F2024),
                          side: BorderSide(
                            color: isDestructive
                                ? Colors.red.shade200
                                : isPositive
                                ? Colors.green.shade200
                                : const Color(0xFFE2E2E6),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: Icon(
                          isDestructive
                              ? Icons.delete_outline
                              : isPositive
                              ? Icons.check_circle_outline
                              : Icons.play_arrow_outlined,
                          size: 16,
                        ),
                        label: Text(
                          adminActionLabel(a),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  );
                }),
              ],

              // Delete record button (owner only)
              if (widget.isOwner &&
                  widget.canWrite &&
                  widget.module.canDelete &&
                  !published) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: Color(0xFFF0EDF0)),
                ),
                SizedBox(
                  width: double.infinity,
                  child: Tooltip(
                    message: 'Delete record',
                    child: TextButton.icon(
                      onPressed: busy ? null : deleteRecord,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text(
                        'Delete This Record',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        if (widget.module.name == 'event_types' &&
            widget.modules.any((module) => module.name == 'category_nodes'))
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: OutlinedButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => AdminEventCategories(
                  repo: widget.repo,
                  eventId: widget.id,
                  canWrite: widget.canWrite,
                ),
              ),
              icon: const Icon(Icons.account_tree_outlined),
              label: const Text('Linked categories'),
            ),
          ),

        // Related Records Card
        if (related().isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF0EDF0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.hub_outlined,
                      size: 18,
                      color: Color(0xFF80152C),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Linked Records',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...related().entries.map((e) {
                  final target = widget.modules
                      .where((m) => m.name == e.key)
                      .firstOrNull;
                  if (target == null) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEFEFF2)),
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        title: Text(
                          target.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 16),
                        onTap: () => openRelated(e.key, e.value),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
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
        backgroundColor: const Color(0xFFF8F8FA),
        appBar: AppBar(
          title: Text(
            row?.title ?? widget.module.label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          actions: [
            IconButton(
              tooltip: 'Reload',
              onPressed: busy ? null : load,
              icon: const Icon(Icons.refresh),
            ),
            if (widget.canWrite &&
                widget.module.editable.isNotEmpty &&
                !published)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.icon(
                  onPressed: busy || row == null ? null : edit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF80152C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                ),
              ),
          ],
        ),
        body: loading && row == null
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF80152C)),
              )
            : row == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 40,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    const Text('Unable to load record details'),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: load,
                      child: const Text('Retry Loading'),
                    ),
                  ],
                ),
              )
            : AbsorbPointer(
                absorbing: busy,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 940;

                    return ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        if (busy || loading)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: LinearProgressIndicator(
                              color: Color(0xFF80152C),
                            ),
                          ),
                        if (error != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber,
                                  color: Colors.amber.shade800,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Refresh failed. Retry before making changes to avoid stale overwrites.',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                                TextButton(
                                  onPressed: load,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),

                        // Header Banner
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFF0EDF0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFBF4F6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.dataset_outlined,
                                  color: Color(0xFF80152C),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF5E8EC),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            widget.module.label.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF80152C),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'ID: ${widget.id.length > 12 ? "${widget.id.substring(0, 12)}…" : widget.id}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      row!.title,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1F2024),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Main body responsive split
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Column: Field Cards + Conversation
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (widget.module.name ==
                                            'support_tickets' &&
                                        row!.values['user_id'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 16,
                                        ),
                                        child: _SupportRequester(
                                          key: ValueKey(row!.values['user_id']),
                                          repo: widget.repo,
                                          modules: widget.modules,
                                          userId: row!.values['user_id']
                                              .toString(),
                                        ),
                                      ),
                                    ..._buildGroupedFields(context),
                                    if (widget.module.name == 'support_tickets')
                                      _Conversation(
                                        repo: widget.repo,
                                        ticketId: widget.id,
                                        refresh: row!.revision,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              // Right Column: Sidebar
                              SizedBox(
                                width: 340,
                                child: _buildSidebar(
                                  context,
                                  published,
                                  fileField,
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildSidebar(context, published, fileField),
                              const SizedBox(height: 20),
                              if (widget.module.name == 'support_tickets' &&
                                  row!.values['user_id'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _SupportRequester(
                                    key: ValueKey(row!.values['user_id']),
                                    repo: widget.repo,
                                    modules: widget.modules,
                                    userId: row!.values['user_id'].toString(),
                                  ),
                                ),
                              ..._buildGroupedFields(context),
                              if (widget.module.name == 'support_tickets')
                                _Conversation(
                                  repo: widget.repo,
                                  ticketId: widget.id,
                                  refresh: row!.revision,
                                ),
                            ],
                          ),
                      ],
                    );
                  },
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

class _ConversationState extends State<_Conversation>
    with LiveDataState<_Conversation> {
  @override
  Set<String> get liveDatasets => {
    'admin:support_messages',
    'admin:support_tickets',
  };
  @override
  Future<void> onLiveData(Set<String> changed) async {
    setState(() {
      messages = fetch();
    });
    await messages;
  }

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
    builder: (c, s) => Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0EDF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.forum_outlined,
                size: 20,
                color: Color(0xFF80152C),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Support Message Thread',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              Text(
                '${s.data?.rows.length ?? 0} messages',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Showing the latest 100 messages in this customer support conversation.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const Divider(height: 24, color: Color(0xFFF0EDF0)),
          if (s.connectionState != ConnectionState.done)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(color: Color(0xFF80152C)),
            ),
          if (s.hasError)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  messages = fetch();
                });
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry conversation fetch'),
            ),
          if ((s.data?.rows ?? []).isEmpty &&
              s.connectionState == ConnectionState.done)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No messages exchanged in this ticket yet.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            ),
          for (final m in s.data?.rows.reversed ?? <AdminRecord>[]) ...[
            Builder(
              builder: (ctx) {
                final isSupport = m.values['sender_role'] == 'support';
                final body = m.values['body']?.toString() ?? '';
                final role = m.values['sender_role']?.toString() ?? '';
                final time = m.values['created_at']?.toString() ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSupport
                        ? const Color(0xFFFBF4F6)
                        : const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSupport
                          ? const Color(0xFF80152C).withValues(alpha: 0.15)
                          : const Color(0xFFE2E2E6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isSupport
                                  ? const Color(0xFF80152C)
                                  : Colors.grey.shade700,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isSupport ? 'SUPPORT' : role.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            time.length > 19
                                ? time.substring(0, 19).replaceAll('T', ' ')
                                : time,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        body,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
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
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF0EDF0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                role == 'customer'
                    ? Icons.person_outline
                    : Icons.storefront_outlined,
                color: const Color(0xFF80152C),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${adminLabel(role)} Requester',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF80152C),
                    ),
                  ),
                  Text(
                    requester.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (requester.values['email'] != null)
                    Text(
                      requester.values['email'].toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
