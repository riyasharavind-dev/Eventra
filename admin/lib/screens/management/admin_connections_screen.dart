import '../../services/app_live_data.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/admin_connections_model.dart';
import '../../models/admin_module.dart';
import '../../repositories/admin_connections_repository.dart';
import '../../repositories/admin_repository.dart';
import '../../widgets/admin_management_helpers.dart';

class AdminConnectionsScreen extends StatefulWidget {
  final AdminConnectionsRepository connections;
  final AdminRepository repo;
  final void Function(String, Map<String, dynamic>) onOpen;
  final bool storageFirst;
  const AdminConnectionsScreen({
    super.key,
    required this.connections,
    required this.repo,
    required this.onOpen,
    this.storageFirst = false,
  });
  @override
  State<AdminConnectionsScreen> createState() => _AdminConnectionsScreenState();
}

class _AdminConnectionsScreenState extends State<AdminConnectionsScreen>
    with LiveDataState<AdminConnectionsScreen> {
  @override
  Set<String> get liveDatasets => {
    'admin:storage',
    'admin:modules',
    'admin:admins',
  };
  @override
  Future<void> onLiveData(Set<String> changed) async {
    refresh();
    await loading;
  }

  late Future<AdminConnections> loading;
  String query = '';
  @override
  void initState() {
    super.initState();
    loading = widget.connections.inventory();
  }

  void refresh() => setState(() => loading = widget.connections.inventory());
  void source(DatabaseConnection source, AdminConnections data) {
    if (source.module != null) {
      widget.onOpen(source.module!, {});
      return;
    }
    if (source.schema == 'public') {
      showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(source.label),
          content: const Text(
            'This source has no management module. Recheck the module catalog.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminConnectionRecordsScreen(
          connections: widget.connections,
          repo: widget.repo,
          source: source,
        ),
      ),
    );
  }

  Widget database(AdminConnections data) {
    final sources = data.sources
        .where(
          (x) =>
              '${x.label} ${x.key} ${x.section}'.toLowerCase().contains(query),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '${data.sources.where((s) => s.schema == 'public' && s.kind == 'table').length} tables · ${data.sources.where((s) => s.schema == 'public' && s.kind == 'view').length} published views · ${data.sources.where((s) => s.schema != 'public').length} system sources',
        ),
        const SizedBox(height: 12),
        const Text(
          'Manage records in their modules. System internals are read-only; request payloads and cached responses are excluded.',
        ),
        for (final section in sources.map((s) => s.section).toSet()) ...[
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 8),
            child: Text(section, style: Theme.of(context).textTheme.titleLarge),
          ),
          for (final s in sources.where((s) => s.section == section))
            Card(
              child: ListTile(
                leading: Icon(
                  s.kind == 'view'
                      ? Icons.visibility_outlined
                      : Icons.table_chart_outlined,
                ),
                title: Text(s.label),
                subtitle: Text(
                  '${s.key}\n${s.rows} records · ${s.kind == 'view'
                      ? (s.invoker ? 'RLS-aware view' : 'Internal view')
                      : s.rls
                      ? 'RLS enabled'
                      : s.schema == 'public'
                      ? 'RLS needs review'
                      : 'Restricted schema'}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => source(s, data),
              ),
            ),
        ],
        if (sources.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No matching database connections.'),
          ),
      ],
    );
  }

  Widget storage(AdminConnections data) {
    final buckets = data.buckets
        .where((b) => '${b.id} ${b.purpose}'.toLowerCase().contains(query))
        .toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '${data.buckets.length} connected buckets · ${data.buckets.fold<int>(0, (sum, b) => sum + b.objects)} files',
        ),
        const SizedBox(height: 12),
        const Text(
          'Uploads stay in the relevant record editor. Public files retain public URLs; private documents use temporary signed links.',
        ),
        const SizedBox(height: 16),
        for (final b in buckets)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(b.isPublic ? Icons.public : Icons.lock_outline),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          b.id,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Chip(
                        label: Text(b.isPublic ? 'Public media' : 'Private'),
                      ),
                    ],
                  ),
                  Text(b.purpose),
                  const SizedBox(height: 8),
                  Text(
                    '${b.objects} files · ${adminBytes(b.bytes)} stored\nUpload limit: ${adminBytes(b.maxBytes)}\n${b.mimeTypes.join(', ')}',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminConnectionRecordsScreen(
                              connections: widget.connections,
                              repo: widget.repo,
                              bucket: b,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Browse files'),
                      ),
                      TextButton(
                        onPressed: () => widget.onOpen(b.module, {}),
                        child: const Text('Open linked module'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (buckets.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No matching storage buckets.'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AdminConnections>(
    future: loading,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: TextButton(
            onPressed: refresh,
            child: const Text('Unable to load connections. Retry'),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final data = snapshot.data!;
      return DefaultTabController(
        length: 2,
        initialIndex: widget.storageFirst ? 1 : 0,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Find table, module or bucket',
                      ),
                      onChanged: (v) =>
                          setState(() => query = v.trim().toLowerCase()),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh connections',
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            const TabBar(
              tabs: [
                Tab(text: 'Database connections'),
                Tab(text: 'Storage buckets'),
              ],
            ),
            Expanded(
              child: TabBarView(children: [database(data), storage(data)]),
            ),
          ],
        ),
      );
    },
  );
}

class AdminConnectionRecordsScreen extends StatefulWidget {
  final AdminConnectionsRepository connections;
  final AdminRepository repo;
  final StorageConnection? bucket;
  final DatabaseConnection? source;
  const AdminConnectionRecordsScreen({
    super.key,
    required this.connections,
    required this.repo,
    this.bucket,
    this.source,
  });
  @override
  State<AdminConnectionRecordsScreen> createState() =>
      _AdminConnectionRecordsScreenState();
}

class _AdminConnectionRecordsScreenState
    extends State<AdminConnectionRecordsScreen>
    with LiveDataState<AdminConnectionRecordsScreen> {
  @override
  Set<String> get liveDatasets => {'*'};
  @override
  Future<void> onLiveData(Set<String> changed) async {
    await load();
  }

  AdminPage? page;
  Object? error;
  bool loading = true;
  int offset = 0, generation = 0;
  String query = '';
  Timer? debounce;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
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
      final result = widget.bucket != null
          ? await widget.connections.objects(
              widget.bucket!.id,
              query: query,
              offset: offset,
            )
          : await widget.connections.system(widget.source!.key, offset: offset);
      if (!mounted || g != generation) return;
      setState(() {
        page = result;
        loading = false;
      });
    } catch (e) {
      if (mounted && g == generation) {
        setState(() {
          error = e;
          loading = false;
        });
      }
    }
  }

  Future<void> file(AdminRecord row) async {
    try {
      final bucket = widget.bucket!, path = row.values['name'] as String;
      final url = await widget.repo.signedFile(bucket.id, path);
      if (!mounted) return;
      final image = (row.values['mime_type'] as String? ?? '').startsWith(
        'image/',
      );
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('File preview'),
          content: SizedBox(
            width: 600,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectableText(path),
                const SizedBox(height: 12),
                if (image)
                  Flexible(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Text(
                        'Preview unavailable. Use a temporary link.',
                      ),
                    ),
                  )
                else
                  const Text(
                    'Copy the temporary link to open this document in your browser.',
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (c.mounted) Navigator.pop(c);
              },
              child: const Text('Copy 5-minute link'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) adminError(context, e);
    }
  }

  void details(AdminRecord row) => showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('System record · read-only'),
      content: SingleChildScrollView(
        child: SelectableText(
          const JsonEncoder.withIndent('  ').convert(row.values),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Close'),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.bucket?.id ?? widget.source!.label),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Column(
      children: [
        if (widget.bucket != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search file paths',
              ),
              onChanged: (v) {
                debounce?.cancel();
                debounce = Timer(const Duration(milliseconds: 300), () {
                  query = v.trim();
                  offset = 0;
                  load();
                });
              },
            ),
          ),
        if (loading) const LinearProgressIndicator(),
        Expanded(
          child: error != null
              ? Center(
                  child: TextButton(
                    onPressed: load,
                    child: const Text('Unable to load records. Retry'),
                  ),
                )
              : page == null
              ? const SizedBox.shrink()
              : page!.rows.isEmpty
              ? const Center(child: Text('No records found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: page!.rows.length,
                  itemBuilder: (c, index) {
                    final row = page!.rows[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          widget.bucket != null
                              ? Icons.insert_drive_file_outlined
                              : Icons.data_object,
                        ),
                        title: Text(
                          widget.bucket != null
                              ? row.values['name'].toString()
                              : row.title,
                        ),
                        subtitle: Text(
                          widget.bucket != null
                              ? '${row.values['mime_type'] ?? 'Unknown type'} · ${adminBytes((row.values['bytes'] as num?)?.toInt())}'
                              : row.values.keys.join(', '),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            widget.bucket != null ? file(row) : details(row),
                      ),
                    );
                  },
                ),
        ),
        if (page != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Text('${page!.total} records'),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Previous page',
                    onPressed: loading || offset == 0
                        ? null
                        : () {
                            offset = (offset - 30).clamp(0, offset);
                            load();
                          },
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    tooltip: 'Next page',
                    onPressed: loading || offset + 30 >= page!.total
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
          ),
      ],
    ),
  );
}
