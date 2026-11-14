import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_module.dart';
import '../repositories/admin_repository.dart';

Future<T?> showAdminRecordPanel<T>(
  BuildContext context,
  WidgetBuilder builder,
) => showGeneralDialog<T>(
  context: context,
  transitionDuration: const Duration(milliseconds: 220),
  pageBuilder: (context, animation, secondaryAnimation) => SafeArea(
    child: Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Material(
          elevation: 12,
          child: SizedBox.expand(child: Builder(builder: builder)),
        ),
      ),
    ),
  ),
  transitionBuilder: (context, animation, secondaryAnimation, child) {
    final direction = Directionality.of(context) == TextDirection.rtl
        ? -1.0
        : 1.0;
    return SlideTransition(
      position: Tween(
        begin: Offset(direction, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
      child: child,
    );
  },
);

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
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: const Color(0xFF262626),
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
        ],
      ),
    ),
  );
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
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    backgroundColor: Colors.white,
    child: SizedBox(
      width: 640,
      height: 580,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.format_list_bulleted,
                    size: 20,
                    color: Color(0xFF80152C),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select ${widget.module.label}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2024),
                        ),
                      ),
                      Text(
                        'Choose an existing ${widget.module.label.toLowerCase()} record to link',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0EDF0)),

          // Search Field
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: query,
              decoration: InputDecoration(
                hintText: 'Search by title, name, or ID…',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: query.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          query.clear();
                          offset = 0;
                          load();
                        },
                      )
                    : IconButton(
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        onPressed: () {
                          offset = 0;
                          load();
                        },
                      ),
                filled: true,
                fillColor: const Color(0xFFF8F8FA),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E2E6)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E2E6)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF80152C),
                    width: 1.5,
                  ),
                ),
              ),
              onSubmitted: (_) {
                offset = 0;
                load();
              },
            ),
          ),

          if (loading) const LinearProgressIndicator(color: Color(0xFF80152C)),

          if (error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Could not load records.'),
                  TextButton(onPressed: load, child: const Text('Retry')),
                ],
              ),
            ),

          // Records List
          Expanded(
            child: (page?.rows.isEmpty ?? false) && !loading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 40,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No ${widget.module.label.toLowerCase()} records found',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: page?.rows.length ?? 0,
                    itemBuilder: (context, index) {
                      final row = page!.rows[index];
                      final rowId = row.id(widget.module);
                      final email = row.values['email']?.toString();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF0EDF0)),
                        ),
                        child: Material(
                          type: MaterialType.transparency,
                          child: ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            title: Text(
                              row.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: Color(0xFF1F2024),
                              ),
                            ),
                            subtitle: Text(
                              email != null
                                  ? '$email · ID: $rowId'
                                  : 'ID: $rowId',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontFamily: 'monospace',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(
                              Icons.check_circle_outline,
                              size: 18,
                              color: Color(0xFF80152C),
                            ),
                            onTap: () => Navigator.pop(context, rowId),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Pagination Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              border: Border(top: BorderSide(color: Color(0xFFF0EDF0))),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Text(
                  '${page?.total ?? 0} total records',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: loading || offset == 0
                      ? null
                      : () {
                          offset = (offset - 30).clamp(0, 1 << 30);
                          load();
                        },
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: 'Next page',
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

    final isDestructive =
        deletion ||
        widget.action == 'suspend_account' ||
        widget.action == 'rejected' ||
        widget.action == 'failed';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDestructive
                  ? Colors.red.shade50
                  : const Color(0xFFFBF4F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isDestructive
                  ? Icons.warning_amber_rounded
                  : Icons.verified_outlined,
              color: isDestructive
                  ? Colors.red.shade700
                  : const Color(0xFF80152C),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${adminActionLabel(widget.action)}?',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDestructive
                        ? Colors.red.shade50
                        : const Color(0xFFF8F8FA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDestructive
                          ? Colors.red.shade200
                          : const Color(0xFFEBEBEF),
                    ),
                  ),
                  child: Text(
                    deletion
                        ? 'This permanently removes the requested Auth account and its dependent records. Resolve active bookings first. Stored files are queued for cleanup.'
                        : widget.action == 'publish'
                        ? 'Publish this draft now? The previous published version will be archived and published text becomes immutable.'
                        : widget.action == 'hidden'
                        ? 'This review will be excluded from public lists and rating averages.'
                        : 'This action is tracked and recorded in the admin activity log.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDestructive
                          ? Colors.red.shade900
                          : Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (deletion) ...[
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Type exact account email',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
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
                        ? 'Reply to Requester'
                        : required
                        ? 'Reason (Required)'
                        : 'Administrative Note (Optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: isDestructive
                ? Colors.red.shade700
                : const Color(0xFF80152C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(context, {
                'reason': text.trim(),
                'body': text.trim(),
                'confirm_email': email.trim(),
              });
            }
          },
          child: Text(isDestructive ? 'Confirm & Apply' : 'Confirm Action'),
        ),
      ],
    );
  }
}
