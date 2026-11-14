import '../../services/app_live_data.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/admin_module.dart';
import '../../repositories/admin_repository.dart';
import '../../widgets/admin_module_card.dart';
import '../../widgets/admin_management_helpers.dart';
import 'admin_record_editor.dart';
import 'admin_record_screen.dart';

class AdminModuleScreen extends StatefulWidget {
  final AdminRepository repo;
  final AdminModule module;
  final List<AdminModule> modules;
  final ({String label, VoidCallback onPressed})? tableTool;
  final bool canWrite, isOwner;
  final Map<String, dynamic> filters;
  const AdminModuleScreen({
    super.key,
    required this.repo,
    required this.module,
    required this.modules,
    this.tableTool,
    this.canWrite = true,
    this.isOwner = false,
    this.filters = const {},
  });
  @override
  State<AdminModuleScreen> createState() => _AdminModuleScreenState();
}

class _AdminModuleScreenState extends State<AdminModuleScreen>
    with LiveDataState<AdminModuleScreen> {
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
      if (!liveRefreshing) loading = true;
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
    final result = await showAdminRecordPanel<AdminRecord>(
      context,
      (_) => AdminRecordEditor(
        repo: widget.repo,
        module: widget.module,
        modules: widget.modules,
        initial: filters,
      ),
    );
    if (result != null && mounted) {
      offset = 0;
      await load();
    }
  }

  Future<void> open(AdminRecord row) async {
    await showAdminRecordPanel<void>(
      context,
      (_) => AdminRecordScreen(
        repo: widget.repo,
        module: widget.module,
        modules: widget.modules,
        id: row.id(widget.module),
        canWrite: widget.canWrite && widget.module.permittedWrite != false,
        isOwner: widget.isOwner,
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
      width: 200,
      child: DropdownButtonFormField<String>(
        key: ValueKey('${widget.module.name}-${field.name}-$current'),
        initialValue: choices.contains(current) ? current : '__any__',
        isExpanded: true,
        decoration: InputDecoration(
          labelText: field.label,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
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

  Widget _cellValue(AdminField? field, dynamic value, String display) {
    final valStr = value?.toString().toLowerCase() ?? display.toLowerCase();

    // Status or boolean badges
    if (field?.name == 'status' || field?.name == 'moderation_status') {
      Color bg = const Color(0xFFF0EDF0);
      Color text = const Color(0xFF73737D);

      if ([
        'accepted',
        'completed',
        'verified',
        'approved',
        'resolved',
        'active',
      ].contains(valStr)) {
        bg = const Color(0xFFE8F5E9);
        text = const Color(0xFF2E7D32);
      } else if ([
        'pending',
        'in_review',
        'under_review',
        'waiting_for_vendor',
      ].contains(valStr)) {
        bg = const Color(0xFFFFF3E0);
        text = const Color(0xFFE65100);
      } else if ([
        'rejected',
        'failed',
        'cancelled',
        'hidden',
        'dismissed',
      ].contains(valStr)) {
        bg = const Color(0xFFFFEBEE);
        text = const Color(0xFFC62828);
      } else if (['draft', 'open'].contains(valStr)) {
        bg = const Color(0xFFF5E8EC);
        text = const Color(0xFF80152C);
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          adminLabel(display).toUpperCase(),
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: text,
          ),
        ),
      );
    }

    if (field?.type == 'bool' ||
        field?.name == 'is_active' ||
        field?.name == 'is_published') {
      final isTrue = valStr == 'true' || valStr == 'yes';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isTrue ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          isTrue ? 'YES' : 'NO',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: isTrue ? const Color(0xFF2E7D32) : const Color(0xFF73737D),
          ),
        ),
      );
    }

    return Text(
      display,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13, color: Color(0xFF17171B)),
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
        .toList();

    return Column(
      children: [
        // Top Toolbar & Compact Header
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.45,
          ),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF0EDF0), width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.tableTool case final tool?)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: tool.onPressed,
                        child: Text(tool.label),
                      ),
                    ),
                  // Row 1: Title, Count Badge, and Primary Action Buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        widget.module.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF17171B),
                          letterSpacing: -0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5E8EC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${page?.total ?? 0} records',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF80152C),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh table',
                        onPressed: load,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                      if (widget.canWrite &&
                          widget.module.permittedWrite != false &&
                          widget.module.canCreate)
                        FilledButton.icon(
                          onPressed: edit,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Record'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                    ],
                  ),

                  if (widget.module.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.module.description,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF73737D),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Row 2: Search Input & Filter Dropdowns in a single line / tidy wrap
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 280,
                        child: TextField(
                          controller: query,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              size: 18,
                              color: Color(0xFF73737D),
                            ),
                            hintText: 'Search ${widget.module.name}…',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFA0A0AC),
                            ),
                            suffixIcon: query.text.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      query.clear();
                                      offset = 0;
                                      load();
                                    },
                                    icon: const Icon(Icons.close, size: 16),
                                  ),
                          ),
                          onChanged: (_) {
                            debounce?.cancel();
                            debounce = Timer(
                              const Duration(milliseconds: 300),
                              () {
                                offset = 0;
                                load();
                              },
                            );
                          },
                        ),
                      ),

                      if (status != null)
                        SizedBox(
                          width: 190,
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('filter-${filters[status.name]}'),
                            initialValue:
                                filters[status.name] as String? ?? 'all',
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: status.label,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
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
                        ),

                      ...extraFilters.map(contentFilter),

                      AdminCapabilityChips(
                        module: widget.module,
                        writable: widget.canWrite,
                      ),
                    ],
                  ),

                  // Row 3: Active Filters Pills (if any custom filters exist)
                  if (filters.keys.any(
                    (k) =>
                        k != status?.name &&
                        !extraFilters.any((f) => f.name == k),
                  )) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: filters.entries
                          .where(
                            (e) =>
                                e.key != status?.name &&
                                !extraFilters.any((f) => f.name == e.key),
                          )
                          .map(
                            (e) => InputChip(
                              label: Text('${adminLabel(e.key)}: ${e.value}'),
                              labelStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: () {
                                setState(() => filters.remove(e.key));
                                offset = 0;
                                load();
                              },
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

        if (loading) const LinearProgressIndicator(color: Color(0xFF80152C)),

        if (error != null)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 36,
                  color: Color(0xFF80152C),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Could not load records for this module.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                TextButton.icon(
                  onPressed: load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),

        // Main Data Records Viewport
        Expanded(
          child: LayoutBuilder(
            builder: (context, size) {
              if (page == null && loading) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF80152C)),
                );
              }
              if (page?.rows.isEmpty ?? true) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: Color(0xFFA0A0AC),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No records match your query or filters.',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF73737D),
                          ),
                        ),
                        if (query.text.isNotEmpty || filters.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              query.clear();
                              filters.clear();
                              offset = 0;
                              load();
                            },
                            child: const Text('Clear all filters'),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFF0EDF0)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF80152C).withValues(alpha: 0.02),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: size.maxWidth - 32,
                        ),
                        child: DataTable(
                          showCheckboxColumn: false,
                          headingRowHeight: 46,
                          dataRowMinHeight: 56,
                          dataRowMaxHeight: 64,
                          columns: [
                            DataColumn(
                              label: Text(
                                widget.module.pk,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: Color(0xFF17171B),
                                ),
                              ),
                            ),
                            ...display.map(
                              (f) => DataColumn(
                                label: Text(
                                  f.name,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: Color(0xFF17171B),
                                  ),
                                ),
                              ),
                            ),
                            const DataColumn(
                              label: Text(
                                'ACTION',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: Color(0xFF17171B),
                                ),
                              ),
                            ),
                          ],
                          rows: page!.rows.map((row) {
                            return DataRow(
                              onSelectChanged: (_) => open(row),
                              cells: [
                                DataCell(
                                  SizedBox(
                                    width: 220,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          row.id(widget.module),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (row.title != row.id(widget.module))
                                          Text(
                                            row.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                ...display.map((f) {
                                  final val = row.values[f.name];
                                  final disp = row.display(f.name);
                                  return DataCell(
                                    SizedBox(
                                      width: f.type == 'timestamptz'
                                          ? 180
                                          : 160,
                                      child: _cellValue(f, val, disp),
                                    ),
                                  );
                                }),
                                DataCell(
                                  TextButton.icon(
                                    onPressed: () => open(row),
                                    icon: const Icon(Icons.more_horiz_rounded),
                                    label: const Text('Row actions'),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Pagination Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFF0EDF0), width: 1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Showing ${page?.total == 0 ? 0 : offset + 1}–${(offset + (page?.rows.length ?? 0))} of ${page?.total ?? 0} records',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF73737D),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Previous page',
                    onPressed: loading || offset == 0
                        ? null
                        : () {
                            offset = (offset - 30).clamp(0, 1 << 30);
                            load();
                          },
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Next page',
                    onPressed: loading || offset + 30 >= (page?.total ?? 0)
                        ? null
                        : () {
                            offset += 30;
                            load();
                          },
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
