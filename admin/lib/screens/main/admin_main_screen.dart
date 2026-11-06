import '../../repositories/admin_connections_repository.dart';
import '../management/admin_connections_screen.dart';

import 'package:flutter/material.dart';

import '../../models/admin_module.dart';
import '../../repositories/admin_repository.dart';
import '../../widgets/admin_management_helpers.dart';
import '../management/admin_dashboard_screen.dart';
import '../management/admin_customer_app_screen.dart';
import '../management/admin_home_feed_screen.dart';
import '../management/admin_module_screen.dart';

class AdminMainScreen extends StatefulWidget {
  final AdminRepository? repository;
  const AdminMainScreen({super.key, this.repository});
  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  late final AdminRepository repo;
  List<AdminModule> modules = [];
  Map<String, dynamic>? session;
  String selected = 'dashboard', moduleSearch = '';
  Map<String, dynamic> filters = {};
  int refreshKey = 0;
  bool loading = true;
  Object? error;
  @override
  void initState() {
    super.initState();
    repo = widget.repository ?? AdminRepository();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final identity = await repo.session();
      if (identity == null) {
        throw StateError('This account has no active admin access.');
      }
      final catalog = await repo.catalog();
      if (mounted) {
        setState(() {
          session = identity;
          modules = catalog;
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

  void open(String name, Map<String, dynamic> values) {
    setState(() {
      selected = name;
      filters = Map<String, dynamic>.from(values);
      refreshKey++;
    });
  }

  Future<void> logout() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sign out of admin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (yes == true) {
      try {
        await repo.db.auth.signOut();
      } catch (e) {
        if (mounted) {
          adminError(context, e);
        }
      }
    }
  }

  Widget navigation({bool drawer = false}) {
    final visible = modules
        .where(
          (m) => '${m.label} ${m.name} ${m.section}'.toLowerCase().contains(
            moduleSearch.toLowerCase(),
          ),
        )
        .toList();
    final sections = visible.map((m) => m.section).toSet();
    return Container(
      width: 260,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EVENTOR',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${session?['name'] ?? 'Admin'} · ${session?['access_level'] ?? ''}',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Find module',
                    ),
                    onChanged: (v) => setState(() => moduleSearch = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  ListTile(
                    selected: selected == 'dashboard',
                    leading: const Icon(Icons.dashboard_outlined),
                    title: const Text('Dashboard'),
                    onTap: () {
                      if (drawer) {
                        Navigator.pop(context);
                      }
                      open('dashboard', {});
                    },
                  ),
                  ListTile(
                    selected: selected == 'database_connections',
                    leading: const Icon(Icons.hub_outlined),
                    title: const Text('Database Connections'),
                    onTap: () {
                      if (drawer) Navigator.pop(context);
                      open('database_connections', {});
                    },
                  ),
                  ListTile(
                    selected: selected == 'storage_buckets',
                    leading: const Icon(Icons.cloud_outlined),
                    title: const Text('Storage Buckets'),
                    onTap: () {
                      if (drawer) Navigator.pop(context);
                      open('storage_buckets', {});
                    },
                  ),
                  ListTile(
                    selected: selected == 'customer_app',
                    leading: const Icon(Icons.phone_android_outlined),
                    title: const Text('Customer App'),
                    onTap: () {
                      if (drawer) Navigator.pop(context);
                      open('customer_app', {});
                    },
                  ),
                  for (final section in sections) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
                      child: Text(
                        section.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    ...visible
                        .where((m) => m.section == section)
                        .map(
                          (m) => ListTile(
                            dense: true,
                            selected: selected == m.name,
                            selectedColor: Theme.of(context)
                                .colorScheme
                                .primary,
                            leading: Icon(_icon(m.section), size: 20),
                            title: Text(m.label),
                            onTap: () {
                              if (drawer) {
                                Navigator.pop(context);
                              }
                              open(m.name, {});
                            },
                          ),
                        ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: logout,
            ),
          ],
        ),
      ),
    );
  }

  IconData _icon(String section) => switch (section) {
    'Accounts & Access' => Icons.manage_accounts_outlined,
    'Businesses & Services' => Icons.storefront_outlined,
    'Catalog & Locations' => Icons.category_outlined,
    'Bookings & History' => Icons.event_note_outlined,
    'Trust & Moderation' => Icons.verified_user_outlined,
    'Customer Experience' => Icons.view_carousel_outlined,
    'Content & Settings' => Icons.article_outlined,
    'Support' => Icons.support_agent,
    'Notifications' => Icons.notifications_outlined,
    'Published Content' => Icons.public,
    _ => Icons.admin_panel_settings_outlined,
  };
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Eventor Admin')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  error.toString().replaceFirst('Bad state: ', ''),
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: load,
                  child: const Text('Retry access check'),
                ),
                TextButton(
                  onPressed: () => repo.db.auth.signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final mobile = MediaQuery.sizeOf(context).width < 950,
        module = modules.where((m) => m.name == selected).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          selected == 'database_connections'
              ? 'Database Connections'
              : selected == 'storage_buckets'
              ? 'Storage Buckets'
              : selected == 'customer_app'
              ? 'Customer App'
              : module?.label ?? 'Dashboard',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh workspace',
            onPressed: () {
              setState(() => refreshKey++);
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Recheck admin permissions',
            onPressed: load,
            icon: const Icon(Icons.admin_panel_settings_outlined),
          ),
        ],
      ),
      drawer: mobile
          ? Drawer(width: 280, child: navigation(drawer: true))
          : null,
      body: Row(
        children: [
          if (!mobile) navigation(),
          if (!mobile) const VerticalDivider(width: 1),
          Expanded(
            child: selected == 'dashboard'
                ? AdminDashboardScreen(
                    key: ValueKey('dashboard-$refreshKey'),
                    repo: repo,
                    modules: modules,
                    onOpen: open,
                  )
                : selected == 'database_connections' ||
                      selected == 'storage_buckets'
                ? AdminConnectionsScreen(
                    key: ValueKey('$selected-$refreshKey'),
                    connections: AdminConnectionsRepository(repo.db),
                    repo: repo,
                    storageFirst: selected == 'storage_buckets',
                    onOpen: open,
                  )
                : selected == 'customer_app'
                ? AdminCustomerAppScreen(
                    key: ValueKey('customer-app-$refreshKey'),
                    repo: repo,
                    modules: modules,
                    onOpen: open,
                  )
                : selected == 'home_feed_sections'
                ? AdminHomeFeedScreen(
                    key: ValueKey('home-feed-$refreshKey'),
                    repo: repo,
                    canWrite: session?['access_level'] != 'viewer',
                  )
                : module == null
                ? const Center(child: Text('Select an admin module.'))
                : AdminModuleScreen(
                    key: ValueKey('${module.name}-$refreshKey'),
                    repo: repo,
                    module: module,
                    modules: modules,
                    filters: filters,
                    canWrite: session?['access_level'] != 'viewer',
                    isOwner: session?['access_level'] == 'owner',
                  ),
          ),
        ],
      ),
    );
  }
}
