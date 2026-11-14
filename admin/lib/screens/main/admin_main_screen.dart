import '../extended/admin_languages_screen.dart';
import '../../services/app_live_data.dart';
import '../../repositories/admin_connections_repository.dart';
import '../extended/admin_team_screen.dart';
import '../extended/admin_catalog_screen.dart';
import '../extended/admin_workspace_screen.dart';
import '../management/admin_connections_screen.dart';

import 'package:flutter/material.dart';

import '../../models/admin_module.dart';
import '../../repositories/admin_repository.dart';
import '../../widgets/admin_management_helpers.dart';
import '../../widgets/confirmation_dialog.dart';
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

class _AdminMainScreenState extends State<AdminMainScreen>
    with LiveDataState<AdminMainScreen> {
  @override
  Set<String> get liveDatasets => {
    'admin:admins',
    'admin:modules',
    'admin:team_permissions',
    'own:access',
    'own:team_permissions',
  };

  @override
  Future<void> onLiveData(Set<String> changed) async {
    await load();
  }

  late final AdminRepository repo;
  List<AdminModule> modules = [];
  Map<String, dynamic>? session;
  String selected = 'workspace', moduleSearch = '';
  Map<String, dynamic> filters = {};
  int refreshKey = 0;
  bool loading = true;
  Object? error;

  final Set<String> _collapsedSections = {};
  final _moduleSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    repo = widget.repository ?? AdminRepository();
    load();
  }

  @override
  void dispose() {
    _moduleSearchController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      if (!liveRefreshing) loading = true;
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
          if (identity['access_level'] != 'owner' &&
              [
                'dashboard',
                'database_connections',
                'storage_buckets',
                'team_access',
              ].contains(selected)) {
            selected = catalog.isEmpty ? 'none' : catalog.first.name;
          }
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
      builder: (c) => const ConfirmationDialog(
        title: 'Sign out of admin?',
        message: 'Are you sure you want to end your current admin session?',
        confirmText: 'Sign out',
        cancelText: 'Cancel',
        confirmColor: Color(0xFF80152C),
        icon: Icons.logout_rounded,
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

  Widget _navItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    String? badge,
    Color? badgeColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF5E8EC) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: const Color(0xFFF2D1DC))
            : Border.all(color: Colors.transparent),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          dense: true,
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onTap: onTap,
          leading: Icon(
            icon,
            size: 20,
            color: isSelected
                ? const Color(0xFF80152C)
                : const Color(0xFF73737D),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? const Color(0xFF80152C)
                  : const Color(0xFF17171B),
            ),
          ),
          trailing: badge != null
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        badgeColor ??
                        const Color(0xFF80152C).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeColor != null
                          ? Colors.white
                          : const Color(0xFF80152C),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {String? keyName}) {
    final isCollapsed = keyName != null && _collapsedSections.contains(keyName);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: Color(0xFF8E8E98),
              ),
            ),
          ),
          if (keyName != null)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                setState(() {
                  if (isCollapsed) {
                    _collapsedSections.remove(keyName);
                  } else {
                    _collapsedSections.add(keyName);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  isCollapsed
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                  size: 16,
                  color: const Color(0xFF8E8E98),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget navigation({bool drawer = false}) {
    final query = moduleSearch.trim().toLowerCase();
    final isOwner = session?['access_level'] == 'owner';

    final visibleModules = modules.where((m) {
      if (query.isEmpty) return true;
      return '${m.label} ${m.name} ${m.section} ${m.description}'
          .toLowerCase()
          .contains(query);
    }).toList();

    return Container(
      width: 275,
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Brand & Identity Header
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF0EDF0), width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF80152C), Color(0xFF650C20)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF80152C)
                                  .withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            'E',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'EVENTOR',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: Color(0xFF80152C),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5E8EC),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ADMIN CONSOLE',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: Color(0xFF80152C),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Table search
                  TextField(
                    controller: _moduleSearchController,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 18,
                        color: Color(0xFF73737D),
                      ),
                      hintText: 'Search tables…',
                      hintStyle: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFFA0A0AC),
                      ),
                      fillColor: const Color(0xFFF8F8FA),
                      filled: true,
                      suffixIcon: moduleSearch.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () =>
                                  setState(() => moduleSearch = ''),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFF0EDF0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFF0EDF0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFF80152C),
                          width: 1.2,
                        ),
                      ),
                    ),
                    onChanged: (v) => setState(() => moduleSearch = v),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (query.isEmpty) ...[
                    _sectionHeader('Workspace'),
                    _tableNav(
                      'workspace',
                      'Control Centre',
                      Icons.space_dashboard_outlined,
                      drawer,
                    ),
                    if (isOwner) ...[
                      _tableNav(
                        'dashboard',
                        'Dashboard',
                        Icons.analytics_outlined,
                        drawer,
                      ),
                      _tableNav(
                        'team_access',
                        'Team & Access',
                        Icons.manage_accounts_outlined,
                        drawer,
                      ),
                      _tableNav(
                        'database_connections',
                        'Database Connections',
                        Icons.hub_outlined,
                        drawer,
                      ),
                      _tableNav(
                        'storage_buckets',
                        'Storage Buckets',
                        Icons.cloud_outlined,
                        drawer,
                      ),
                    ],
                  ],
                  if (visibleModules.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No matching tables'),
                    ),
                  for (final section
                      in visibleModules.map((m) => m.section).toSet()) ...[
                    _sectionHeader(
                      section,
                      keyName: query.isEmpty ? section : null,
                    ),
                    if (query.isNotEmpty ||
                        !_collapsedSections.contains(section))
                      for (final table in visibleModules.where(
                        (m) => m.section == section,
                      ))
                        _tableNav(
                          table.name,
                          table.name,
                          _icon(section),
                          drawer,
                          active: _tableToolTarget(selected) == table.name,
                        ),
                  ],
                ],
              ),
            ),

            // User Profile & Sign Out Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFF0EDF0), width: 1),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: const Color(0xFF80152C),
                    child: Text(
                      ((session?['name'] as String?)?.isNotEmpty == true)
                          ? (session!['name'] as String)
                                .substring(0, 1)
                                .toUpperCase()
                          : 'A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session?['name']?.toString() ?? 'Administrator',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF17171B),
                          ),
                        ),
                        Text(
                          (session?['access_level']?.toString() ?? 'staff')
                              .toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: session?['access_level'] == 'owner'
                                ? const Color(0xFFB8860B)
                                : const Color(0xFF80152C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sign out',
                    onPressed: logout,
                    icon: const Icon(
                      Icons.logout_rounded,
                      size: 20,
                      color: Color(0xFF73737D),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _tableToolTarget(String route) => switch (route) {
    'language_tools' => 'app_languages',
    'home_feed_tools' => 'home_feed_sections',
    _ => null,
  };

  Widget _tableNav(
    String destination,
    String title,
    IconData icon,
    bool drawer, {
    bool active = false,
  }) => _navItem(
    icon: icon,
    title: title,
    isSelected: selected == destination || active,
    onTap: () {
      if (drawer) Navigator.pop(context);
      open(destination, {});
    },
  );

  IconData _icon(String section) => switch (section) {
    'Accounts & Access' => Icons.manage_accounts_outlined,
    'Businesses & Services' => Icons.storefront_outlined,
    'Catalog & Locations' => Icons.category_outlined,
    'Bookings & History' => Icons.event_note_outlined,
    'Trust & Moderation' => Icons.verified_user_outlined,
    'Customer Experience' => Icons.view_carousel_outlined,
    'Content & Settings' => Icons.article_outlined,
    'Support' => Icons.support_agent_outlined,
    'Notifications' => Icons.notifications_outlined,
    'Published Content' => Icons.public,
    _ => Icons.admin_panel_settings_outlined,
  };

  String _screenTitle(AdminModule? module) {
    return switch (selected) {
      'workspace' => 'Control Centre',
      'shared_catalog' => 'Categories & Event Types',
      'team_access' => 'Team & Permissions',
      'database_connections' => 'Database Connections',
      'storage_buckets' => 'Storage Buckets',
      'customer_app' => 'Customer App Studio',
      'dashboard' => 'Executive Dashboard',
      'home_feed_tools' => 'Home Feed Editor',
      'language_tools' => 'Languages & Releases',
      _ => module?.name ?? 'Dashboard',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF80152C)),
        ),
      );
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
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFF80152C),
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  error.toString().replaceFirst('Bad state: ', ''),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry access check'),
                ),
                const SizedBox(height: 8),
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

    final mobile = MediaQuery.sizeOf(context).width < 950;
    final module = modules.where((m) => m.name == selected).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: mobile ? null : 16,
        leading: mobile
            ? Builder(
                builder: (c) => IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(c).openDrawer(),
                ),
              )
            : null,
        title: Row(
          children: [
            if (!mobile) ...[
              const Text(
                'Admin',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF73737D),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: Color(0xFFA0A0AC),
                ),
              ),
            ],
            Flexible(
              child: Text(
                _screenTitle(module),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF17171B),
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Live realtime indicator badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFC8E6C9)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E7D32),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Live',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Refresh workspace',
            onPressed: () => setState(() => refreshKey++),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Recheck admin permissions',
            onPressed: load,
            icon: const Icon(Icons.admin_panel_settings_outlined),
          ),
          const SizedBox(width: 10),
        ],
      ),
      drawer: mobile
          ? Drawer(width: 290, child: navigation(drawer: true))
          : null,
      body: Row(
        children: [
          if (!mobile) navigation(),
          if (!mobile)
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: Color(0xFFF0EDF0),
            ),
          Expanded(
            child: selected == 'workspace'
                ? AdminWorkspaceScreen(
                    key: ValueKey('workspace-$refreshKey'),
                    isOwner: session?['access_level'] == 'owner',
                    modules: modules,
                    onOpen: open,
                    canWrite: (name) =>
                        session?['access_level'] == 'owner' ||
                        session?['access_level'] == 'admin' ||
                        (session?['access_level'] == 'staff' &&
                            (session?['permissions'] as Map?)?[name] == true),
                  )
                : selected == 'shared_catalog'
                ? AdminCatalogScreen(
                    key: ValueKey('catalog-$refreshKey'),
                    repo: repo,
                    modules: modules,
                    onOpen: open,
                    canWrite: (name) =>
                        session?['access_level'] == 'owner' ||
                        session?['access_level'] == 'admin' ||
                        (session?['access_level'] == 'staff' &&
                            (session?['permissions'] as Map?)?[name] == true),
                  )
                : selected == 'language_tools' &&
                      modules.any(
                        (table) =>
                            table.name == 'app_languages' ||
                            table.name == 'app_language_releases',
                      )
                ? AdminLanguagesScreen(
                    key: ValueKey('languages-$refreshKey'),
                    canWrite:
                        session?['access_level'] == 'owner' ||
                        session?['access_level'] == 'admin' ||
                        (session?['access_level'] == 'staff' &&
                            (session?['permissions']
                                    as Map?)?['app_languages'] ==
                                true),
                    canPublish:
                        session?['access_level'] == 'owner' ||
                        session?['access_level'] == 'admin' ||
                        (session?['access_level'] == 'staff' &&
                            (session?['permissions']
                                    as Map?)?['app_language_releases'] ==
                                true),
                  )
                : selected == 'team_access'
                ? AdminTeamScreen(key: ValueKey('team-$refreshKey'))
                : selected == 'dashboard'
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
                : selected == 'home_feed_tools' &&
                      modules.any((table) => table.name == 'home_feed_sections')
                ? AdminHomeFeedScreen(
                    key: ValueKey('home-feed-$refreshKey'),
                    repo: repo,
                    canWrite:
                        session?['access_level'] == 'owner' ||
                        session?['access_level'] == 'admin' ||
                        (session?['access_level'] == 'staff' &&
                            (session?['permissions']
                                    as Map?)?['home_feed_sections'] ==
                                true),
                  )
                : module == null
                ? const Center(child: Text('Select a table.'))
                : AdminModuleScreen(
                    key: ValueKey('${module.name}-$refreshKey'),
                    repo: repo,
                    module: module,
                    modules: modules,
                    tableTool: switch (module.name) {
                      'app_languages' || 'app_language_releases' => (
                        label: 'Translation & publishing',
                        onPressed: () => open('language_tools', {}),
                      ),
                      'home_feed_sections' => (
                        label: 'Feed editor',
                        onPressed: () => open('home_feed_tools', {}),
                      ),
                      _ => null,
                    },
                    filters: filters,
                    canWrite:
                        session?['access_level'] == 'owner' ||
                        session?['access_level'] == 'admin' ||
                        (session?['access_level'] == 'staff' &&
                            (session?['permissions'] as Map?)?[selected] ==
                                true),
                    isOwner: session?['access_level'] == 'owner',
                  ),
          ),
        ],
      ),
    );
  }
}
