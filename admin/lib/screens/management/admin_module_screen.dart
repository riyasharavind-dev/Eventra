import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/admin_module.dart';
import '../../repositories/admin_repository.dart';
import '../../widgets/admin_module_card.dart';
import 'admin_record_editor.dart';
import 'admin_record_screen.dart';

class AdminModuleScreen extends StatefulWidget {
  final AdminRepository repo;
  final AdminModule module;
  final List<AdminModule> modules;
  final bool canWrite, isOwner;
  final Map<String, dynamic> filters;
  const AdminModuleScreen({
    super.key,
    required this.repo,
    required this.module,
    required this.modules,
    this.canWrite = true,
    this.isOwner = false,
    this.filters = const {},
  });
  @override
  State<AdminModuleScreen> createState() => _AdminModuleScreenState();
}

class _AdminModuleScreenState extends State<AdminModuleScreen> {
  final query = TextEditingController();
  Timer? debounce;
  AdminPage? page;
  bool loading = true;
  Object? error;
  int offset = 0, generation = 0;
  late Map<String, dynamic> filters;
  @override
  void initState() {
    super.initState();
    filters = Map<String, dynamic>.from(widget.filters);
    load();
  }

  @override
  void dispose() {
    query.dispose();
    debounce?.cancel();
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
        offset: offset,
        filters: filters,
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

  Future<void> edit() async {
    final result = await Navigator.push<AdminRecord>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminRecordEditor(
          repo: widget.repo,
          module: widget.module,
          modules: widget.modules,
          initial: filters,
        ),
      ),
    );
    if (result != null && mounted) {
      offset = 0;
      await load();
    }
  }

  Future<void> open(AdminRecord row) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AdminRecordScreen(
          repo: widget.repo,
          module: widget.module,
          modules: widget.modules,
          id: row.id(widget.module),
          canWrite: widget.canWrite && widget.module.permittedWrite != false,
          isOwner: widget.isOwner,
        ),
      ),
    );
    if (mounted) {
      await load();
    }
  }

  Widget contentFilter(AdminField field) {
    final choices = field.choices.isNotEmpty
        ? field.choices
        : switch (field.name) {
            'audience' =>
              widget.module.name.contains('social')
                  ? ['vendor', 'customer', 'all']
                  : ['vendor', 'customer'],
            'language_code' => ['en', 'ta'],
            'document_type' => ['terms_and_conditions', 'privacy_policy'],
            'sender_role' => ['vendor', 'customer', 'support'],
            _ => ['true', 'false'],
          };
    final current = filters[field.name]?.toString();
    return SizedBox(
      width: 230,
      child: DropdownButtonFormField<String>(
        key: ValueKey('${widget.module.name}-${field.name}-$current'),
        initialValue: choices.contains(current) ? current : '__any__',
        isExpanded: true,
        decoration: InputDecoration(
          labelText: field.label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          const DropdownMenuItem(value: '__any__', child: Text('Any')),
          ...choices.map(
            (value) => DropdownMenuItem(
              value: value,
              child: Text(
                field.type == 'bool'
                    ? (value == 'true' ? 'Yes' : 'No')
                    : adminLabel(value),
              ),
            ),
          ),
        ],
        onChanged: (value) {
          setState(() {
            if (value == null || value == '__any__') {
              filters.remove(field.name);
            } else {
              filters[field.name] = field.type == 'bool'
                  ? value == 'true'
                  : value;
            }
            offset = 0;
          });
          load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.module.fields
        .where(
          (f) =>
              [
                'status',
                'moderation_status',
                'availability_status',
              ].contains(f.name) &&
              f.choices.isNotEmpty,
        )
        .firstOrNull;
    final extraFilters = widget.module.fields
        .where(
          (f) =>
              [
                'audience',
                'language_code',
                'document_type',
                'sender_role',
                'is_published',
                'is_active',
              ].contains(f.name) ||
              (f.name == 'category' && f.choices.isNotEmpty),
        )
        .toList();
    final display = widget.module.fields
        .where(
          (f) =>
              ![
                'id',
                'created_by',
                'updated_at',
                'token',
                'description',
                'content_markdown',
                'features',
                'gallery',
                'portfolio',
                'before_data',
                'after_data',
                'files',
              ].contains(f.name) &&
              f.name != widget.module.pk,
        )
        .take(5)
        .toList();
    return LayoutBuilder(
      builder: (context, bounds) => Column(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: bounds.maxHeight * 0.52),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${widget.module.label} · ${page?.total ?? 0}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: load,
                          icon: const Icon(Icons.refresh),
                        ),
                        if (widget.canWrite && widget.module.canCreate)
                          FilledButton.icon(
                            onPressed: edit,
                            icon: const Icon(Icons.add),
                            label: const Text('Add'),
                          ),
                      ],
                    ),
                    if (widget.module.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          widget.module.description,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    AdminCapabilityChips(
                      module: widget.module,
                      writable: widget.canWrite,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: query,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Search ${widget.module.label.toLowerCase()}',
                        border: const OutlineInputBorder(),
                        suffixIcon: query.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  query.clear();
                                  offset = 0;
                                  load();
                                },
                                icon: const Icon(Icons.close),
                              ),
                      ),
                      onChanged: (_) {
                        debounce?.cancel();
                        debounce = Timer(const Duration(milliseconds: 300), () {
                          offset = 0;
                          load();
                        });
                      },
                    ),
                    if (status != null) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey('filter-${filters[status.name]}'),
                        initialValue: filters[status.name] as String? ?? 'all',
                        decoration: InputDecoration(
                          labelText: status.label,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('All statuses'),
                          ),
                          ...status.choices.map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(adminLabel(s)),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == null || v == 'all') {
                            filters.remove(status.name);
                          } else {
                            filters[status.name] = v;
                          }
                          offset = 0;
                          load();
                        },
                      ),
                    ],
                    if (extraFilters.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: extraFilters.map(contentFilter).toList(),
                      ),
                    ],
                    if (filters.keys.any(
                      (k) =>
                          k != status?.name &&
                          !extraFilters.any((f) => f.name == k),
                    )) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: filters.entries
                            .where(
                              (e) =>
                                  e.key != status?.name &&
                                  !extraFilters.any((f) => f.name == e.key),
                            )
                            .map(
                              (e) => Chip(
                                label: Text('${adminLabel(e.key)}: ${e.value}'),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (loading) const LinearProgressIndicator(),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Could not load this module.'),
                  TextButton(onPressed: load, child: const Text('Retry')),
                ],
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, size) {
                if (page == null && loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (page?.rows.isEmpty ?? true) {
                  return const Center(child: Text('No matching records.'));
                }
                if (size.maxWidth >= 850) {
                  return SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        showCheckboxColumn: false,
                        columns: [
                          DataColumn(label: Text(widget.module.label)),
                          ...display.map(
                            (f) => DataColumn(label: Text(f.label)),
                          ),
                        ],
                        rows: page!.rows
                            .map(
                              (row) => DataRow(
                                onSelectChanged: (_) => open(row),
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 220,
                                      child: Text(
                                        row.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  ...display.map(
                                    (f) => DataCell(
                                      SizedBox(
                                        width: f.type == 'timestamptz'
                                            ? 190
                                            : 170,
                                        child: Text(
                                          row.display(f.name),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: load,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: page!.rows.length,
                    itemBuilder: (context, index) {
                      final row = page!.rows[index];
                      return Card(
                        child: ListTile(
                          title: Text(row.title),
                          subtitle: Text(
                            display
                                .take(3)
                                .map(
                                  (f) => '${f.label}: ${row.display(f.name)}',
                                )
                                .join('\n'),
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => open(row),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${page?.total == 0 ? 0 : offset + 1}–${(offset + (page?.rows.length ?? 0))} of ${page?.total ?? 0}',
                ),
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
    );
  }
}
