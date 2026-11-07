import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_module.dart';
import '../repositories/admin_repository.dart';

String adminRequestId() {
  final random = Random.secure(), b = List<int>.generate(16, (_) => 0);
  for (var i = 0; i < b.length; i++) {
    b[i] = random.nextInt(256);
  }
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

void adminError(BuildContext context, Object error) {
  String message = error is PostgrestException
      ? error.message
      : error is AuthException
      ? error.message
      : error
            .toString()
            .replaceFirst('Bad state: ', '')
            .replaceFirst('FormatException: ', '');
  if (error is PostgrestException && error.code == '23505') {
    message = 'A record with these details already exists.';
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String adminActionLabel(String action) =>
    const {
      'suspend_account': 'Suspend account',
      'restore_account': 'Restore account',
      'accepted': 'Accept booking',
      'rejected': 'Reject',
      'completed': 'Mark completed',
      'cancelled': 'Cancel booking',
      'under_review': 'Start review',
      'verified': 'Verify',
      'resubmission_required': 'Request resubmission',
      'expired': 'Mark expired',
      'not_applicable': 'Not applicable',
      'approved': 'Approve',
      'manual_review': 'Manual identity review',
      'failed': 'Mark failed',
      'visible': 'Restore visibility',
      'hidden': 'Hide review',
      'resolved': 'Resolve',
      'dismissed': 'Dismiss report',
      'reply': 'Reply to requester',
      'open': 'Reopen',
      'in_progress': 'In progress',
      'waiting_for_vendor': 'Awaiting requester reply',
      'closed': 'Close ticket',
      'new_version': 'Create new draft version',
      'publish': 'Publish draft',
      'archive': 'Archive version',
      'categories': 'Manage categories',
      'in_review': 'Start request review',
      'delete_account': 'Delete requested account',
      'revoke': 'Revoke device token',
      'activate': 'Activate access',
      'deactivate': 'Deactivate access',
      'cleanup_completed': 'Retry storage cleanup',
    }[action] ??
    adminLabel(action);
List<String> availableAdminActions(
  AdminModule module,
  AdminRecord row, {
  bool owner = false,
}) {
  final v = row.values;
  return module.actions.where((a) {
    if (module.name == 'users') {
      if (!owner || row.values['_managed_admin'] == true) return false;
      return a == 'suspend_account'
          ? row.values['_account_suspended'] != true
          : row.values['_account_suspended'] == true;
    }
    if (module.name == 'bookings') {
      return v['status'] == 'pending'
          ? ['accepted', 'rejected', 'cancelled'].contains(a)
          : v['status'] == 'accepted'
          ? ['completed', 'cancelled'].contains(a)
          : false;
    }
    if (module.name == 'legal_documents') {
      return a == 'new_version'
          ? true
          : a == 'publish'
          ? v['status'] == 'draft'
          : v['status'] == 'published';
    }
    if (module.name == 'admins') {
      return owner &&
          (a == 'activate'
              ? !(v['is_active'] == true)
              : v['is_active'] == true);
    }
    if (module.name == 'account_deletion_requests') {
      return ['pending', 'in_review'].contains(v['status']) &&
          (a != 'delete_account' || (owner && v['status'] == 'in_review'));
    }
    if (module.name == 'admin_storage_cleanup') {
      return v['status'] == 'pending';
    }
    if (module.name == 'service_reviews') {
      return a != v['moderation_status'];
    }
    if (module.name == 'service_review_reports') {
      return v['status'] == 'open';
    }
    return true;
  }).toList();
}

Future<String?> pickAdminReference(
  BuildContext context,
  AdminRepository repo,
  AdminModule module, {
  Map<String, dynamic> filters = const {},
}) => showDialog<String>(
  context: context,
  builder: (_) =>
      _ReferencePicker(repo: repo, module: module, filters: filters),
);

class _ReferencePicker extends StatefulWidget {
  final AdminRepository repo;
  final AdminModule module;
  final Map<String, dynamic> filters;
  const _ReferencePicker({
    required this.repo,
    required this.module,
    required this.filters,
  });
  @override
  State<_ReferencePicker> createState() => _ReferencePickerState();
}

class _ReferencePickerState extends State<_ReferencePicker> {
  final query = TextEditingController();
  AdminPage? page;
  bool loading = true;
  Object? error;
  int offset = 0, generation = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final g = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.repo.records(
        widget.module.name,
        search: query.text,
        filters: widget.filters,
        offset: offset,
      );
      if (mounted && g == generation) {
        setState(() {
          page = result;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted && g == generation) {
        setState(() {
          error = e;
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: SizedBox(
      width: 620,
      height: 560,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Select ${widget.module.label}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: query,
              decoration: InputDecoration(
                hintText: 'Search and press Enter',
                suffixIcon: IconButton(
                  onPressed: () {
                    offset = 0;
                    load();
                  },
                  icon: const Icon(Icons.search),
                ),
              ),
              onSubmitted: (_) {
                offset = 0;
                load();
              },
            ),
          ),
          if (loading) const LinearProgressIndicator(),
          if (error != null)
            TextButton(
              onPressed: load,
              child: const Text('Could not load. Retry'),
            ),
          Expanded(
            child: ListView(
              children: [
                for (final row in page?.rows ?? [])
                  ListTile(
                    title: Text(row.title),
                    subtitle: Text(
                      row.values['email']?.toString() ?? row.id(widget.module),
                    ),
                    onTap: () => Navigator.pop(context, row.id(widget.module)),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('${page?.total ?? 0} records'),
              IconButton(
                onPressed: loading || offset == 0
                    ? null
                    : () {
                        offset = (offset - 30).clamp(0, 1 << 30);
                        load();
                      },
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                onPressed: loading || offset + 30 >= (page?.total ?? 0)
                    ? null
                    : () {
                        offset += 30;
                        load();
                      },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Future<Map<String, dynamic>?> confirmAdminAction(
  BuildContext context,
  String action,
) => showDialog<Map<String, dynamic>>(
  context: context,
  builder: (_) => _ActionDialog(action: action),
);

class _ActionDialog extends StatefulWidget {
  final String action;
  const _ActionDialog({required this.action});
  @override
  State<_ActionDialog> createState() => _ActionDialogState();
}

class _ActionDialogState extends State<_ActionDialog> {
  final form = GlobalKey<FormState>();
  String text = '', email = '';
  @override
  Widget build(BuildContext context) {
    final reply = widget.action == 'reply',
        deletion = widget.action == 'delete_account';
    final required = [
      'rejected',
      'resubmission_required',
      'visible',
      'hidden',
      'resolved',
      'dismissed',
      'failed',
      'manual_review',
      'delete_account',
      'revoke',
      'suspend_account',
      'restore_account',
    ].contains(widget.action);
    return AlertDialog(
      title: Text('${adminActionLabel(widget.action)}?'),
      content: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                deletion
                    ? 'This permanently removes the requested Auth account and its dependent records. Resolve active bookings first. Stored files are queued for cleanup.'
                    : widget.action == 'publish'
                    ? 'Publish this draft now? The previous published version is archived and published text becomes immutable.'
                    : widget.action == 'hidden'
                    ? 'This review is excluded from public lists and rating averages.'
                    : 'This action is recorded in the admin activity log.',
              ),
              const SizedBox(height: 16),
              if (deletion) ...[
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Type exact account email',
                  ),
                  onChanged: (v) => email = v,
                  validator: (v) => v?.contains('@') == true
                      ? null
                      : 'Enter the account email',
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                maxLines: reply ? 6 : 3,
                maxLength: reply ? 4000 : 1000,
                decoration: InputDecoration(
                  labelText: reply
                      ? 'Reply to requester'
                      : required
                      ? 'Reason (required)'
                      : 'Note (optional)',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => text = v,
                validator: (v) =>
                    (reply || required) &&
                        (v?.trim().length ?? 0) <
                            (reply
                                ? 1
                                : [
                                    'suspend_account',
                                    'restore_account',
                                  ].contains(widget.action)
                                ? 5
                                : 3)
                    ? 'Enter a ${reply ? 'reply' : 'reason'}'
                    : null,
              ),
            ],
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
                'reason': text.trim(),
                'body': text.trim(),
                'confirm_email': email.trim(),
              });
            }
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
