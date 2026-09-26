import 'package:flutter/material.dart';

import '../../widgets/admin_sidebar.dart';

import '../banners/banners_screen.dart';
import '../categories/category_screen.dart';
import '../event_types/event_types_screen.dart';
import '../services/services_screen.dart';
import '../vendors/vendors_screen.dart';
import '../customers/customers_screen.dart';
import '../bookings/bookings_screen.dart';

class AdminMainScreen
    extends StatefulWidget {
  const AdminMainScreen({
    super.key,
  });

  @override
  State<AdminMainScreen> createState() =>
      _AdminMainScreenState();
}

class _AdminMainScreenState
    extends State<AdminMainScreen> {
  // ===========================================================================
  // CURRENT SECTION
  // ===========================================================================

  AdminSection _currentSection =
      AdminSection.dashboard;

  // ===========================================================================
  // REFRESH KEYS
  // ===========================================================================

  int _bannersRefreshKey = 0;

  int _eventTypesRefreshKey = 0;

  int _categoriesRefreshKey = 0;

  int _servicesRefreshKey = 0;

  int _vendorsRefreshKey = 0;

  int _customersRefreshKey = 0;

  int _bookingsRefreshKey = 0;

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final bool isMobile =
        MediaQuery.sizeOf(context).width <
            900;

    return Scaffold(
      appBar: _buildAppBar(
        context,
        isMobile,
      ),

      drawer: isMobile
          ? _buildMobileDrawer()
          : null,

      body: Row(
        children: [
          if (!isMobile)
            AdminSidebar(
              currentSection:
                  _currentSection,
              onSectionSelected:
                  _selectSection,
            ),

          Expanded(
            child:
                _buildWorkspace(),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // APP BAR
  // ===========================================================================

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    bool isMobile,
  ) {
    return AppBar(
      automaticallyImplyLeading:
          isMobile,

      title: Text(
        _getSectionTitle(),
        style:
            const TextStyle(
          fontWeight:
              FontWeight.w700,
        ),
      ),

      actions: [
        if (_currentSection ==
            AdminSection.banners)
          IconButton(
            tooltip:
                'Refresh Banners',
            onPressed:
                _refreshCurrentSection,
            icon:
                const Icon(
              Icons.refresh,
            ),
          ),

        if (_currentSection ==
            AdminSection.eventTypes)
          IconButton(
            tooltip:
                'Refresh Event Types',
            onPressed:
                _refreshCurrentSection,
            icon:
                const Icon(
              Icons.refresh,
            ),
          ),

        if (_currentSection ==
            AdminSection.categories)
          IconButton(
            tooltip:
                'Refresh Categories',
            onPressed:
                _refreshCurrentSection,
            icon:
                const Icon(
              Icons.refresh,
            ),
          ),

        if (_currentSection ==
            AdminSection.services)
          IconButton(
            tooltip:
                'Refresh Services',
            onPressed:
                _refreshCurrentSection,
            icon:
                const Icon(
              Icons.refresh,
            ),
          ),

        if (_currentSection ==
            AdminSection.vendors)
          IconButton(
            tooltip:
                'Refresh Vendors',
            onPressed:
                _refreshCurrentSection,
            icon:
                const Icon(
              Icons.refresh,
            ),
          ),

        if (_currentSection ==
            AdminSection.customers)
          IconButton(
            tooltip:
                'Refresh Customers',
            onPressed:
                _refreshCurrentSection,
            icon:
                const Icon(
              Icons.refresh,
            ),
          ),

        if (_currentSection ==
            AdminSection.bookings)
          IconButton(
            tooltip:
                'Refresh Bookings',
            onPressed:
                _refreshCurrentSection,
            icon:
                const Icon(
              Icons.refresh,
            ),
          ),

        const SizedBox(
          width: 8,
        ),
      ],
    );
  }

  // ===========================================================================
  // REFRESH
  // ===========================================================================

  void _refreshCurrentSection() {
    setState(() {
      switch (_currentSection) {
        case AdminSection.dashboard:
          break;

        case AdminSection.banners:
          _bannersRefreshKey++;
          break;

        case AdminSection.categories:
          _categoriesRefreshKey++;
          break;

        case AdminSection.eventTypes:
          _eventTypesRefreshKey++;
          break;

        case AdminSection.services:
          _servicesRefreshKey++;
          break;

        case AdminSection.packages:
          break;

        case AdminSection.plans:
          break;

        case AdminSection.collabs:
          break;

        case AdminSection.vendors:
          _vendorsRefreshKey++;
          break;

        case AdminSection.customers:
          _customersRefreshKey++;
          break;

        case AdminSection.bookings:
          _bookingsRefreshKey++;
          break;

        case AdminSection.settings:
          break;
      }
    });
  }

  // ===========================================================================
  // SECTION TITLE
  // ===========================================================================

  String _getSectionTitle() {
    switch (_currentSection) {
      case AdminSection.dashboard:
        return 'Dashboard';

      case AdminSection.banners:
        return 'Banners';

      case AdminSection.categories:
        return 'Categories';

      case AdminSection.eventTypes:
        return 'Event Types';

      case AdminSection.services:
        return 'Services';

      case AdminSection.packages:
        return 'Packages';

      case AdminSection.plans:
        return 'Plans';

      case AdminSection.collabs:
        return 'Collabs';

      case AdminSection.vendors:
        return 'Vendors';

      case AdminSection.customers:
        return 'Customers';

      case AdminSection.bookings:
        return 'Bookings';

      case AdminSection.settings:
        return 'Settings';
    }
  }

  // ===========================================================================
  // SELECT SECTION
  // ===========================================================================

  void _selectSection(
    AdminSection section,
  ) {
    setState(() {
      _currentSection = section;
    });

    if (MediaQuery.sizeOf(context).width <
        900) {
      final navigator =
          Navigator.of(context);

      if (navigator.canPop()) {
        navigator.pop();
      }
    }
  }

  // ===========================================================================
  // WORKSPACE
  // ===========================================================================

  Widget _buildWorkspace() {
    switch (_currentSection) {
      // ========================================================================
      // DASHBOARD
      // ========================================================================

      case AdminSection.dashboard:
        return const _ComingSoonScreen(
          title: 'Dashboard',
          icon:
              Icons.dashboard_outlined,
          description:
              'Eventra administration dashboard will be built here.',
        );

      // ========================================================================
      // BANNERS
      // ========================================================================

      case AdminSection.banners:
        return BannersScreen(
          key: ValueKey(
            'banners_$_bannersRefreshKey',
          ),
        );

      // ========================================================================
      // CATEGORIES
      // ========================================================================

      case AdminSection.categories:
        return CategoryScreen(
          key: ValueKey(
            'categories_$_categoriesRefreshKey',
          ),
        );

      // ========================================================================
      // EVENT TYPES
      // ========================================================================

      case AdminSection.eventTypes:
        return EventTypesScreen(
          key: ValueKey(
            'event_types_$_eventTypesRefreshKey',
          ),
        );

      // ========================================================================
      // SERVICES
      // ========================================================================

      case AdminSection.services:
        return ServicesScreen(
          key: ValueKey(
            'services_$_servicesRefreshKey',
          ),
        );

      // ========================================================================
      // PACKAGES
      // ========================================================================

      case AdminSection.packages:
        return const _ComingSoonScreen(
          title: 'Packages',
          icon:
              Icons.inventory_2_outlined,
          description:
              'Package management will be connected here.',
        );

      // ========================================================================
      // PLANS
      // ========================================================================

      case AdminSection.plans:
        return const _ComingSoonScreen(
          title: 'Plans',
          icon:
              Icons.view_agenda_outlined,
          description:
              'Event plan management will be connected here.',
        );

      // ========================================================================
      // COLLABS
      // ========================================================================

      case AdminSection.collabs:
        return const _ComingSoonScreen(
          title: 'Collabs',
          icon:
              Icons.handshake_outlined,
          description:
              'Vendor collaboration management will be connected here.',
        );

      // ========================================================================
      // VENDORS
      // ========================================================================

      case AdminSection.vendors:
        return VendorsScreen(
          key: ValueKey(
            'vendors_$_vendorsRefreshKey',
          ),
        );

      // ========================================================================
      // CUSTOMERS
      // ========================================================================

      case AdminSection.customers:
        return CustomersScreen(
          key: ValueKey(
            'customers_$_customersRefreshKey',
          ),
        );

      // ========================================================================
      // BOOKINGS
      // ========================================================================

      case AdminSection.bookings:
        return BookingsScreen(
          key: ValueKey(
            'bookings_$_bookingsRefreshKey',
          ),
        );

      // ========================================================================
      // SETTINGS
      // ========================================================================

      case AdminSection.settings:
        return const _ComingSoonScreen(
          title: 'Settings',
          icon:
              Icons.settings_outlined,
          description:
              'Admin settings will be connected here.',
        );
    }
  }

  // ===========================================================================
  // MOBILE DRAWER
  // ===========================================================================

  Widget _buildMobileDrawer() {
    return SafeArea(
      child: Drawer(
        child: AdminSidebar(
          currentSection:
              _currentSection,
          onSectionSelected:
              _selectSection,
        ),
      ),
    );
  }
}

// ==============================================================================
// COMING SOON
// ==============================================================================

class _ComingSoonScreen
    extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _ComingSoonScreen({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Center(
      child:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(32),

        child: Column(
          mainAxisSize:
              MainAxisSize.min,

          children: [
            Container(
              width: 90,
              height: 90,

              decoration:
                  BoxDecoration(
                color: theme
                    .colorScheme
                    .primaryContainer,
                borderRadius:
                    BorderRadius.circular(
                  24,
                ),
              ),

              child: Icon(
                icon,
                size: 46,
                color: theme
                    .colorScheme
                    .onPrimaryContainer,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            Text(
              title,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontSize: 24,
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              description,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color: Colors.grey,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}