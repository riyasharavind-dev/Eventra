import '../../services/app_live_data.dart';

import 'dart:math';

import 'package:flutter/material.dart';

import '../../repositories/admin_repository.dart';

class AdminHomeFeedScreen extends StatefulWidget {
  final AdminRepository repo;
  final bool canWrite;
  const AdminHomeFeedScreen({
    super.key,
    required this.repo,
    required this.canWrite,
  });
  @override
  State<AdminHomeFeedScreen> createState() => _AdminHomeFeedScreenState();
}

class _AdminHomeFeedScreenState extends State<AdminHomeFeedScreen>
    with LiveDataState<AdminHomeFeedScreen> {
  @override
  Set<String> get liveDatasets => {
    'admin:home_feed_sections',
    'admin:home_feed_pinned_items',
    'admin:category_nodes',
    'admin:event_types',
    'admin:services',
    'admin:vendors',
  };
  @override
  Future<void> onLiveData(Set<String> changed) async {
    await load();
  }

  Map<String, dynamic>? workspace;
  Object? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final value = Map<String, dynamic>.from(
        await widget.repo.db.rpc('admin_home_feed_workspace') as Map,
      );
      if (mounted) {
        setState(() {
          workspace = value;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> edit([Map<String, dynamic>? row]) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _FeedEditor(repo: widget.repo, workspace: workspace!, row: row),
    );
    if (changed == true) await load();
  }

  @override
  Widget build(BuildContext context) {
    if (workspace == null) {
      return Center(
        child: error == null
            ? const CircularProgressIndicator(color: Color(0xFF80152C))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Unable to load Home Feed workspace.'),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: load, child: const Text('Retry')),
                ],
              ),
      );
    }
    final rows = workspace!['sections'] as List;

    return RefreshIndicator(
      onRefresh: load,
      color: const Color(0xFF80152C),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF4F6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.feed_outlined,
                    color: Color(0xFF80152C),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customer Home Feed Architecture',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Arrange sections with display order. Combine rules, curate pins, preview saved drafts, and control live customer app feeds.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.canWrite)
                  FilledButton.icon(
                    onPressed: () => edit(),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF80152C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create Section'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                'Refresh failed: $error',
                style: TextStyle(color: Colors.red.shade900, fontSize: 13),
              ),
            ),

          // Section cards
          if (rows.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  children: [
                    Icon(
                      Icons.layers_clear_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    const Text('No home feed sections created yet.'),
                  ],
                ),
              ),
            )
          else
            ...rows.map((raw) {
              final row = Map<String, dynamic>.from(raw as Map);
              final isActive = row['is_active'] == true;
              final contentType =
                  row['content_type']?.toString().toUpperCase() ?? 'SERVICES';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFFF0EDF0)
                        : const Color(0xFFEBEBEB),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.01),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFFFBF4F6)
                            : const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '#${row['sort_order'] ?? 0}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? const Color(0xFF80152C)
                                : Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          row['title'].toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.green.shade50
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isActive ? 'ACTIVE' : 'DRAFT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isActive
                                  ? Colors.green.shade800
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '$contentType · ${row['selection_mode']} selection · ${row['layout']} cards',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          label: const Text(
                            'Preview',
                            style: TextStyle(fontSize: 12),
                          ),
                          onPressed: () => previewFeed(
                            context,
                            widget.repo,
                            row['id'].toString(),
                          ),
                        ),
                        if (widget.canWrite) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Edit section',
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => edit(row),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

Future<void> previewFeed(
  BuildContext context,
  AdminRepository repo,
  String id,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _FeedPreview(repo: repo, id: id),
  );
}

class _FeedPreview extends StatefulWidget {
  final AdminRepository repo;
  final String id;
  const _FeedPreview({required this.repo, required this.id});
  @override
  State<_FeedPreview> createState() => _FeedPreviewState();
}

class _FeedPreviewState extends State<_FeedPreview> {
  Map<String, dynamic>? result;
  Object? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = Map<String, dynamic>.from(
        await widget.repo.db.rpc(
          'admin_home_feed_preview',
          params: {'p_id': widget.id},
        ) as Map,
      );
      if (mounted) setState(() => result = data);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.preview_outlined,
            color: Color(0xFF80152C),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'Saved Section Live Preview',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ],
    ),
    content: SizedBox(
      width: 640,
      height: 480,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Simulated preview including hidden and scheduled sections.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Refresh preview',
                onPressed: busy ? null : load,
              ),
            ],
          ),
          if (busy) const LinearProgressIndicator(color: Color(0xFF80152C)),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text('$error', style: const TextStyle(color: Colors.red)),
            ),
          if (result?['requires_location'] == true)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This section is dynamic and filters by the customer’s active address.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              children: [
                for (final raw in result?['items'] as List? ?? [])
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        title: Text(
                          raw['name'].toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          '★ ${raw['rating'] ?? '—'} · ${raw['completed_count']} completed · ₹${raw['price']}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: raw['image_url'] == null
                              ? Container(
                                  width: 44,
                                  height: 44,
                                  color: Colors.grey.shade200,
                                  child: const Icon(
                                    Icons.image_outlined,
                                    size: 20,
                                  ),
                                )
                              : Image.network(
                                  raw['image_url'].toString(),
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, error, stack) => Container(
                                    width: 44,
                                    height: 44,
                                    color: Colors.grey.shade200,
                                    child: const Icon(
                                      Icons.image_outlined,
                                      size: 20,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                if (result != null &&
                    (result!['items'] as List).isEmpty &&
                    result!['requires_location'] != true)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No matching records found. This section will be hidden on the customer app.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}

class _FeedEditor extends StatefulWidget {
  final AdminRepository repo;
  final Map<String, dynamic> workspace;
  final Map<String, dynamic>? row;
  const _FeedEditor({required this.repo, required this.workspace, this.row});
  @override
  State<_FeedEditor> createState() => _FeedEditorState();
}

class _FeedEditorState extends State<_FeedEditor>
    with SingleTickerProviderStateMixin {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  final pins = <Map<String, dynamic>>[];
  late Map<String, dynamic> rules;
  late TabController tabCtrl;

  String kind = 'services',
      layout = 'horizontal',
      mode = 'automatic',
      sort = 'newest';
  String? id, revision;
  bool active = false, verified = false, busy = false, changed = false;
  String? error;
  DateTime? start, end;
  List<dynamic> districts = [], subdistricts = [];
  late String requestId;

  String uuid() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  void initState() {
    super.initState();
    tabCtrl = TabController(length: 4, vsync: this);
    requestId = uuid();
    final row = widget.row ?? {};
    id = row['id'] as String?;
    revision = row['_revision'] as String?;
    kind = row['content_type']?.toString() ?? kind;
    layout = row['layout']?.toString() ?? layout;
    mode = row['selection_mode']?.toString() ?? mode;
    sort = row['sort_by']?.toString() ?? sort;
    active = row['is_active'] == true;
    rules = Map<String, dynamic>.from(row['rules'] as Map? ?? {});
    verified = rules['verified_only'] == true;
    for (final key in [
      'title',
      'item_limit',
      'sort_order',
      'min_price',
      'max_price',
      'min_rating',
      'min_reviews',
      'new_days',
    ]) {
      fields[key] = TextEditingController(
        text:
            (row[key] ??
                    rules[key] ??
                    (key == 'item_limit'
                        ? 8
                        : key == 'sort_order'
                        ? 0
                        : ''))
                .toString(),
      );
    }
    start = DateTime.tryParse(row['starts_at']?.toString() ?? '')?.toLocal();
    end = DateTime.tryParse(row['ends_at']?.toString() ?? '')?.toLocal();
    for (final pin in row['pins'] as List? ?? []) {
      pins.add(
        pin is Map
            ? Map<String, dynamic>.from(pin)
            : {'id': pin.toString(), 'name': pin.toString()},
      );
    }
    loadRegions();
  }

  Future<void> loadRegions() async {
    try {
      final d = rules['state_id'] == null
          ? <dynamic>[]
          : await widget.repo.db.rpc(
              'admin_home_feed_choices',
              params: {'p_type': 'district', 'p_parent': rules['state_id']},
            ) as List;
      final s = rules['district_id'] == null
          ? <dynamic>[]
          : await widget.repo.db.rpc(
              'admin_home_feed_choices',
              params: {
                'p_type': 'subdistrict',
                'p_parent': rules['district_id'],
              },
            ) as List;
      if (mounted) {
        setState(() {
          districts = d;
          subdistricts = s;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  @override
  void dispose() {
    tabCtrl.dispose();
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget choice(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String> change,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label-$value'),
      initialValue: options.containsKey(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: options.entries
          .map(
            (e) => DropdownMenuItem(
              value: e.key,
              child: Text(e.value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: busy
          ? null
          : (v) {
              if (v != null) setState(() => change(v));
            },
    ),
  );

  Widget ruleChoice(
    String label,
    String key,
    List<dynamic> options, {
    VoidCallback? changed,
  }) => choice(
    label,
    rules[key]?.toString() ?? '',
    {
      '': 'Any',
      for (final row in options) row['id'].toString(): row['name'].toString(),
    },
    (value) {
      if (value.isEmpty) {
        rules.remove(key);
      } else {
        rules[key] = value;
      }
      changed?.call();
    },
  );

  Widget input(String key, String label, {bool number = true}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: fields[key],
      enabled: !busy,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: (v) {
        if (key == 'title') {
          return (v?.trim().isEmpty ?? true) ? 'Title required' : null;
        }
        if (v?.trim().isEmpty ?? true) {
          return ['item_limit', 'sort_order'].contains(key) ? 'Required' : null;
        }
        final n = num.tryParse(v!.trim());
        if (n == null || !n.isFinite || (key != 'sort_order' && n < 0)) {
          return 'Enter a valid number';
        }
        if ([
              'item_limit',
              'sort_order',
              'min_reviews',
              'new_days',
            ].contains(key) &&
            int.tryParse(v.trim()) == null) {
          return 'Enter a whole number';
        }
        if (key == 'item_limit' && (n < 1 || n > 20)) return 'Choose 1–20';
        if (key == 'min_rating' && n > 5) return 'Maximum 5';
        return null;
      },
    ),
  );

  Future<void> schedule(bool isStart) async {
    final current = (isStart ? start : end) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time != null && mounted) {
      setState(() {
        final d = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        if (isStart) {
          start = d;
        } else {
          end = d;
        }
      });
    }
  }

  Future<void> addPins() async {
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PinPicker(repo: widget.repo, kind: kind),
    );
    if (selected != null &&
        mounted &&
        !pins.any((p) => p['id'] == selected['id'])) {
      setState(() => pins.add(selected));
    }
  }

  Future<void> save({bool preview = false}) async {
    if (!form.currentState!.validate() || busy) return;
    if (start != null && end != null && !end!.isAfter(start!)) {
      setState(() => error = 'End must be after start');
      return;
    }
    final outputRules = Map<String, dynamic>.from(rules)
      ..removeWhere(
        (k, v) => [
          'min_price',
          'max_price',
          'min_rating',
          'min_reviews',
          'new_days',
          'verified_only',
        ].contains(k),
      );
    for (final key in [
      'min_price',
      'max_price',
      'min_rating',
      'min_reviews',
      'new_days',
    ]) {
      if (fields[key]!.text.trim().isNotEmpty) {
        outputRules[key] = num.parse(fields[key]!.text.trim());
      }
    }
    if (verified) outputRules['verified_only'] = true;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final saved = Map<String, dynamic>.from(
        await widget.repo.db.rpc(
          'admin_home_feed_save',
          params: {
            'p_data': {
              'title': fields['title']!.text.trim(),
              'content_type': kind,
              'layout': layout,
              'selection_mode': mode,
              'sort_by': sort,
              'item_limit': int.parse(fields['item_limit']!.text),
              'sort_order': int.parse(fields['sort_order']!.text),
              'rules': outputRules,
              'is_active': active,
              'starts_at': start?.toUtc().toIso8601String(),
              'ends_at': end?.toUtc().toIso8601String(),
            },
            'p_pins': mode == 'automatic'
                ? <String>[]
                : pins.map((p) => p['id']).toList(),
            'p_id': id,
            'p_revision': revision,
            'p_request_id': id == null ? requestId : null,
          },
        ) as Map,
      );
      if (!mounted) return;
      id = saved['id'].toString();
      revision = saved['_revision'].toString();
      changed = true;
      if (preview) {
        await previewFeed(context, widget.repo, id!);
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFBF4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.dashboard_customize_outlined,
            color: Color(0xFF80152C),
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          id == null ? 'Create Feed Section' : 'Edit Feed Section',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ],
    ),
    content: SizedBox(
      width: 720,
      height: 560,
      child: Form(
        key: form,
        child: Column(
          children: [
            // Tabs
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: tabCtrl,
                indicatorColor: const Color(0xFF80152C),
                labelColor: const Color(0xFF80152C),
                unselectedLabelColor: Colors.grey.shade600,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(text: 'General'),
                  Tab(text: 'Rules & Filters'),
                  Tab(text: 'Curated Pins'),
                  Tab(text: 'Schedule'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (busy) const LinearProgressIndicator(color: Color(0xFF80152C)),
            if (error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  error!,
                  style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                ),
              ),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: tabCtrl,
                children: [
                  // Tab 1: General
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        input('title', 'Section title', number: false),
                        choice(
                          'Content type',
                          kind,
                          {'services': 'Services', 'vendors': 'Vendors'},
                          (v) {
                            if (kind != v) pins.clear();
                            kind = v;
                          },
                        ),
                        choice('Layout style', layout, {
                          'horizontal': 'Horizontal scroll cards',
                          'grid': 'Two-column grid',
                        }, (v) => layout = v),
                        choice('Selection mode', mode, {
                          'automatic': 'Automatic rules only',
                          'manual': 'Manual picks only',
                          'mixed': 'Pinned items first + automatic fill',
                        }, (v) => mode = v),
                        choice('Sort order strategy', sort, {
                          'newest': 'Newest additions first',
                          'rating': 'Highest customer ratings',
                          'bookings': 'Most completed bookings',
                          'nearest': 'Same sub-district / neighborhood',
                          'price_low': 'Price: lowest to highest',
                          'price_high': 'Price: highest to lowest',
                        }, (v) => sort = v),
                        Row(
                          children: [
                            Expanded(
                              child: input(
                                'item_limit',
                                'Preview cards limit (1–20)',
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: input(
                                'sort_order',
                                'Section display priority order',
                              ),
                            ),
                          ],
                        ),
                        SwitchListTile(
                          value: active,
                          activeThumbColor: const Color(0xFF80152C),
                          onChanged: busy
                              ? null
                              : (v) => setState(() => active = v),
                          title: const Text('Publish / enable section'),
                          subtitle: const Text(
                            'When enabled, section is served on customer app.',
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tab 2: Rules & Filters
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (mode == 'manual')
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Selection mode is set to Manual. Automatic rules do not apply.',
                            ),
                          )
                        else ...[
                          ruleChoice(
                            'Target category',
                            'category_id',
                            widget.workspace['categories'] as List,
                          ),
                          ruleChoice(
                            'Event type',
                            'event_type_id',
                            widget.workspace['events'] as List,
                          ),
                          ruleChoice(
                            'State filter',
                            'state_id',
                            widget.workspace['states'] as List,
                            changed: () {
                              rules.remove('district_id');
                              rules.remove('subdistrict_id');
                              districts = [];
                              subdistricts = [];
                              loadRegions();
                            },
                          ),
                          if (rules['state_id'] != null)
                            ruleChoice(
                              'District filter',
                              'district_id',
                              districts,
                              changed: () {
                                rules.remove('subdistrict_id');
                                subdistricts = [];
                                loadRegions();
                              },
                            ),
                          if (rules['district_id'] != null)
                            ruleChoice(
                              'Sub-district filter',
                              'subdistrict_id',
                              subdistricts,
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: input('min_price', 'Min price (₹)'),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: input('max_price', 'Max price (₹)'),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: input('min_rating', 'Min rating (0–5)'),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: input(
                                  'min_reviews',
                                  'Min reviews count',
                                ),
                              ),
                            ],
                          ),
                          input(
                            'new_days',
                            'Added within the last N days (e.g. 30)',
                          ),
                          SwitchListTile(
                            value: verified,
                            activeThumbColor: const Color(0xFF80152C),
                            onChanged: busy
                                ? null
                                : (v) => setState(() => verified = v),
                            title: const Text('Verified partners only'),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Tab 3: Curated Pins
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (mode == 'automatic')
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Selection mode is set to Automatic. Pins are not used.',
                          ),
                        )
                      else ...[
                        Row(
                          children: [
                            Text(
                              'Pinned Items (${pins.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed: busy ? null : addPins,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF80152C),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.add, size: 16),
                              label: Text('Add $kind'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: pins.isEmpty
                              ? Center(
                                  child: Text(
                                    'No items pinned. Click "Add $kind" to select.',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: pins.length,
                                  itemBuilder: (ctx, i) => Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAFAFA),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFEEEEEE),
                                      ),
                                    ),
                                    child: Material(
                                      type: MaterialType.transparency,
                                      child: ListTile(
                                        dense: true,
                                        leading: Text(
                                          '#${i + 1}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        title: Text(pins[i]['name'].toString()),
                                        subtitle: Text(
                                          pins[i]['id'].toString(),
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 11,
                                          ),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (i > 0)
                                              IconButton(
                                                iconSize: 18,
                                                onPressed: busy
                                                    ? null
                                                    : () => setState(() {
                                                        final p = pins.removeAt(
                                                          i,
                                                        );
                                                        pins.insert(i - 1, p);
                                                      }),
                                                icon: const Icon(
                                                  Icons.arrow_upward,
                                                ),
                                              ),
                                            IconButton(
                                              iconSize: 18,
                                              onPressed: busy
                                                  ? null
                                                  : () => setState(
                                                      () => pins.removeAt(i),
                                                    ),
                                              icon: const Icon(Icons.close),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ],
                  ),

                  // Tab 4: Schedule
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBF4F6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Optional active schedule: Set a start time for promotions or an end time for seasonal sections.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF80152C),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E2E6)),
                          ),
                          child: Material(
                            type: MaterialType.transparency,
                            child: ListTile(
                              leading: const Icon(
                                Icons.play_circle_outline,
                                color: Color(0xFF80152C),
                              ),
                              title: const Text('Start Date & Time (Optional)'),
                              subtitle: Text(
                                start?.toString() ??
                                    'Immediately active upon publication',
                              ),
                              onTap: busy ? null : () => schedule(true),
                              trailing: start != null
                                  ? IconButton(
                                      onPressed: busy
                                          ? null
                                          : () => setState(() => start = null),
                                      icon: const Icon(Icons.clear),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E2E6)),
                          ),
                          child: Material(
                            type: MaterialType.transparency,
                            child: ListTile(
                              leading: const Icon(
                                Icons.stop_circle_outlined,
                                color: Colors.grey,
                              ),
                              title: const Text('End Date & Time (Optional)'),
                              subtitle: Text(
                                end?.toString() ??
                                    'Runs indefinitely with no expiration',
                              ),
                              onTap: busy ? null : () => schedule(false),
                              trailing: end != null
                                  ? IconButton(
                                      onPressed: busy
                                          ? null
                                          : () => setState(() => end = null),
                                      icon: const Icon(Icons.clear),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context, changed),
        child: const Text('Cancel'),
      ),
      OutlinedButton.icon(
        onPressed: busy ? null : () => save(preview: true),
        icon: const Icon(Icons.visibility_outlined, size: 16),
        label: const Text('Save & Preview'),
      ),
      FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF80152C)),
        onPressed: busy ? null : save,
        icon: const Icon(Icons.check, size: 16),
        label: const Text('Save Changes'),
      ),
    ],
  );
}

class _PinPicker extends StatefulWidget {
  final AdminRepository repo;
  final String kind;
  const _PinPicker({required this.repo, required this.kind});
  @override
  State<_PinPicker> createState() => _PinPickerState();
}

class _PinPickerState extends State<_PinPicker> {
  final query = TextEditingController();
  List<dynamic> rows = [];
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    search();
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> search() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await widget.repo.db.rpc(
        'admin_home_feed_choices',
        params: {'p_type': widget.kind, 'p_search': query.text},
      );
      if (mounted) setState(() => rows = data as List);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    title: Text(
      'Select ${widget.kind == 'services' ? 'Service' : 'Vendor'} to Pin',
    ),
    content: SizedBox(
      width: 520,
      height: 460,
      child: Column(
        children: [
          TextField(
            controller: query,
            onSubmitted: (_) => search(),
            decoration: InputDecoration(
              hintText: 'Search by title or vendor name…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: IconButton(
                onPressed: loading ? null : search,
                icon: const Icon(Icons.arrow_forward, size: 18),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (loading) const LinearProgressIndicator(color: Color(0xFF80152C)),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: rows.isEmpty && !loading
                ? const Center(child: Text('No results found.'))
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (ctx, i) {
                      final row = rows[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFAFA),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEEEEEE)),
                        ),
                        child: Material(
                          type: MaterialType.transparency,
                          child: ListTile(
                            dense: true,
                            title: Text(
                              row['name'].toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              row['id'].toString(),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.add_circle_outline,
                              color: Color(0xFF80152C),
                            ),
                            onTap: () => Navigator.pop(
                              context,
                              Map<String, dynamic>.from(row as Map),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}
