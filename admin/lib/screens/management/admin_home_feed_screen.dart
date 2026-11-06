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

class _AdminHomeFeedScreenState extends State<AdminHomeFeedScreen> {
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
            ? const CircularProgressIndicator()
            : TextButton(
                onPressed: load,
                child: const Text('Unable to load Home Feed. Retry'),
              ),
      );
    }
    final rows = workspace!['sections'] as List;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 12,
            children: [
              const Text(
                'Customer Home Feed',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              if (widget.canWrite)
                FilledButton.icon(
                  onPressed: () => edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('Create section'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Arrange sections with Display order. Combine rules, curate pins, preview a saved draft, then enable publication. Empty results are hidden in the customer app.',
          ),
          if (error != null) Text('Refresh failed: $error'),
          const SizedBox(height: 20),
          for (final raw in rows)
            Builder(
              builder: (context) {
                final row = Map<String, dynamic>.from(raw as Map);
                return Card(
                  child: ListTile(
                    title: Text(row['title'].toString()),
                    subtitle: Text(
                      '${row['content_type']} · ${row['selection_mode']} · order ${row['sort_order']} · ${row['is_active'] == true ? 'Enabled (schedule applies)' : 'Draft / hidden'}',
                    ),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: 'Preview saved section',
                          icon: const Icon(Icons.visibility_outlined),
                          onPressed: () => previewFeed(
                            context,
                            widget.repo,
                            row['id'].toString(),
                          ),
                        ),
                        if (widget.canWrite)
                          IconButton(
                            tooltip: 'Edit section',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => edit(row),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
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
  final lat = TextEditingController(), lng = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (_) => _FeedPreview(repo: repo, id: id, lat: lat, lng: lng),
  );
  lat.dispose();
  lng.dispose();
}

class _FeedPreview extends StatefulWidget {
  final AdminRepository repo;
  final String id;
  final TextEditingController lat, lng;
  const _FeedPreview({
    required this.repo,
    required this.id,
    required this.lat,
    required this.lng,
  });
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
          params: {
            'p_id': widget.id,
            'p_lat': double.tryParse(widget.lat.text),
            'p_lng': double.tryParse(widget.lng.text),
          },
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
    title: const Text('Saved section preview'),
    content: SizedBox(
      width: 600,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Preview includes hidden/scheduled sections. Nearby rules require a test location.',
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.lat,
                    decoration: const InputDecoration(
                      labelText: 'Test latitude',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: widget.lng,
                    decoration: const InputDecoration(
                      labelText: 'Test longitude',
                    ),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: busy ? null : load,
              child: const Text('Refresh preview'),
            ),
            if (busy) const LinearProgressIndicator(),
            if (error != null) Text('$error'),
            if (result?['requires_location'] == true)
              const Text(
                'Set both coordinates to preview this nearby section.',
              ),
            for (final raw in result?['items'] as List? ?? [])
              ListTile(
                title: Text(raw['name'].toString()),
                subtitle: Text(
                  'Rating ${raw['rating'] ?? '—'} · ${raw['completed_count']} completed · ₹${raw['price']}',
                ),
                leading: raw['image_url'] == null
                    ? const Icon(Icons.image_outlined)
                    : Image.network(
                        raw['image_url'].toString(),
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stack) =>
                            const Icon(Icons.image_outlined),
                      ),
              ),
            if (result != null &&
                (result!['items'] as List).isEmpty &&
                result!['requires_location'] != true)
              const Text('No eligible results. This section will be hidden.'),
          ],
        ),
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

class _FeedEditorState extends State<_FeedEditor> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  final pins = <Map<String, dynamic>>[];
  late Map<String, dynamic> rules;
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
      'radius_km',
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
        border: const OutlineInputBorder(),
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
        border: const OutlineInputBorder(),
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
          'radius_km',
          'verified_only',
        ].contains(k),
      );
    for (final key in [
      'min_price',
      'max_price',
      'min_rating',
      'min_reviews',
      'new_days',
      'radius_km',
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
    title: Text(id == null ? 'Create Home section' : 'Edit Home section'),
    content: SizedBox(
      width: 700,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              choice('Layout', layout, {
                'horizontal': 'Horizontal cards',
                'grid': 'Two-column grid',
              }, (v) => layout = v),
              choice('Selection mode', mode, {
                'automatic': 'Automatic rules',
                'manual': 'Manual picks only',
                'mixed': 'Pinned first + automatic',
              }, (v) => mode = v),
              if (mode != 'manual') ...[
                ruleChoice(
                  'Category (includes descendants)',
                  'category_id',
                  widget.workspace['categories'] as List,
                ),
                ruleChoice(
                  'Event type',
                  'event_type_id',
                  widget.workspace['events'] as List,
                ),
                ruleChoice(
                  'State',
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
                    'District',
                    'district_id',
                    districts,
                    changed: () {
                      rules.remove('subdistrict_id');
                      subdistricts = [];
                      loadRegions();
                    },
                  ),
                if (rules['district_id'] != null)
                  ruleChoice('Sub-district', 'subdistrict_id', subdistricts),
                input('min_price', 'Minimum service price (optional)'),
                input('max_price', 'Maximum service price (optional)'),
                input('min_rating', 'Minimum rating, 0–5 (optional)'),
                input('min_reviews', 'Minimum visible reviews (optional)'),
                input('new_days', 'Joined / added in last N days (optional)'),
                input('radius_km', 'Maximum distance in km (optional)'),
                SwitchListTile(
                  value: verified,
                  onChanged: busy ? null : (v) => setState(() => verified = v),
                  title: const Text('Verified vendors only'),
                ),
              ],
              if (mode != 'automatic') ...[
                const Text('Pinned order (only eligible, active items appear)'),
                for (var i = 0; i < pins.length; i++)
                  ListTile(
                    title: Text(pins[i]['name'].toString()),
                    subtitle: Text(pins[i]['id'].toString()),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          onPressed: busy || i == 0
                              ? null
                              : () => setState(() {
                                  final p = pins.removeAt(i);
                                  pins.insert(i - 1, p);
                                }),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          onPressed: busy
                              ? null
                              : () => setState(() => pins.removeAt(i)),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                TextButton.icon(
                  onPressed: busy ? null : addPins,
                  icon: const Icon(Icons.add),
                  label: const Text('Select vendor / service'),
                ),
              ],
              choice('Sort by', sort, {
                'newest': 'Newest',
                'rating': 'Highest rated',
                'bookings': 'Most completed bookings',
                'nearest': 'Nearest shop',
                'price_low': 'Price: low to high',
                'price_high': 'Price: high to low',
              }, (v) => sort = v),
              input('item_limit', 'Home preview cards (1–20)'),
              input('sort_order', 'Display order (lower first)'),
              ListTile(
                title: const Text('Start (optional)'),
                subtitle: Text(start?.toString() ?? 'Immediately'),
                onTap: busy ? null : () => schedule(true),
                trailing: IconButton(
                  onPressed: busy ? null : () => setState(() => start = null),
                  icon: const Icon(Icons.clear),
                ),
              ),
              ListTile(
                title: const Text('End (optional)'),
                subtitle: Text(end?.toString() ?? 'No expiry'),
                onTap: busy ? null : () => schedule(false),
                trailing: IconButton(
                  onPressed: busy ? null : () => setState(() => end = null),
                  icon: const Icon(Icons.clear),
                ),
              ),
              SwitchListTile(
                value: active,
                onChanged: busy ? null : (v) => setState(() => active = v),
                title: const Text('Publish / enable section'),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (busy) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context, changed),
        child: const Text('Close'),
      ),
      OutlinedButton(
        onPressed: busy ? null : () => save(preview: true),
        child: const Text('Save & Preview'),
      ),
      FilledButton(
        onPressed: busy ? null : save,
        child: const Text('Save changes'),
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
    title: Text('Select ${widget.kind}'),
    content: SizedBox(
      width: 500,
      height: 450,
      child: Column(
        children: [
          TextField(
            controller: query,
            onSubmitted: (_) => search(),
            decoration: InputDecoration(
              hintText: 'Search by name',
              suffixIcon: IconButton(
                onPressed: loading ? null : search,
                icon: const Icon(Icons.search),
              ),
            ),
          ),
          if (loading) const LinearProgressIndicator(),
          if (error != null) Text(error!),
          Expanded(
            child: ListView(
              children: [
                for (final row in rows)
                  ListTile(
                    title: Text(row['name'].toString()),
                    subtitle: Text(row['id'].toString()),
                    onTap: () => Navigator.pop(
                      context,
                      Map<String, dynamic>.from(row as Map),
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
        child: const Text('Cancel'),
      ),
    ],
  );
}
