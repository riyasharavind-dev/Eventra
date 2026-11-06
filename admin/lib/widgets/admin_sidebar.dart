import 'package:flutter/material.dart';

enum AdminSection {
  dashboard,
  banners,
  categories,
  eventTypes,
  services,
  packages,
  plans,
  collabs,
  vendors,
  customers,
  bookings,
  settings,
}

class AdminSidebar extends StatelessWidget {
  final AdminSection currentSection;

  final ValueChanged<AdminSection>
      onSectionSelected;

  const AdminSidebar({
    super.key,
    required this.currentSection,
    required this.onSectionSelected,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: 250,

      decoration: BoxDecoration(
        color:
            Theme.of(context)
                .colorScheme
                .surface,

        border: Border(
          right: BorderSide(
            color:
                Theme.of(context)
                    .colorScheme
                    .outlineVariant,
          ),
        ),
      ),

      child: SafeArea(
        child: Column(
          children: [
            _header(context),

            const SizedBox(
              height: 8,
            ),

            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                ),

                children: [
                  _sectionLabel(
                    'MAIN',
                  ),

                  _item(
                    context,
                    icon:
                        Icons.dashboard_outlined,
                    selectedIcon:
                        Icons.dashboard,
                    title: 'Dashboard',
                    section:
                        AdminSection.dashboard,
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  _sectionLabel(
                    'MARKETPLACE',
                  ),

                  // ==========================================================
                  // BANNERS
                  // ==========================================================

                  _item(
                    context,
                    icon:
                        Icons.view_carousel_outlined,
                    selectedIcon:
                        Icons.view_carousel,
                    title: 'Banners',
                    section:
                        AdminSection.banners,
                  ),

                  _item(
                    context,
                    icon:
                        Icons.account_tree_outlined,
                    selectedIcon:
                        Icons.account_tree,
                    title: 'Categories',
                    section:
                        AdminSection.categories,
                  ),

                  _item(
                    context,
                    icon:
                        Icons.event_outlined,
                    selectedIcon:
                        Icons.event,
                    title: 'Event Types',
                    section:
                        AdminSection.eventTypes,
                  ),

                  _item(
                    context,
                    icon: Icons
                        .miscellaneous_services_outlined,
                    selectedIcon: Icons
                        .miscellaneous_services,
                    title: 'Services',
                    section:
                        AdminSection.services,
                  ),

                  _item(
                    context,
                    icon:
                        Icons.inventory_2_outlined,
                    selectedIcon:
                        Icons.inventory_2,
                    title: 'Packages',
                    section:
                        AdminSection.packages,
                  ),

                  _item(
                    context,
                    icon:
                        Icons.view_agenda_outlined,
                    selectedIcon:
                        Icons.view_agenda,
                    title: 'Plans',
                    section:
                        AdminSection.plans,
                  ),

                  _item(
                    context,
                    icon:
                        Icons.handshake_outlined,
                    selectedIcon:
                        Icons.handshake,
                    title: 'Collabs',
                    section:
                        AdminSection.collabs,
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  _sectionLabel(
                    'PEOPLE',
                  ),

                  _item(
                    context,
                    icon:
                        Icons.storefront_outlined,
                    selectedIcon:
                        Icons.storefront,
                    title: 'Vendors',
                    section:
                        AdminSection.vendors,
                  ),

                  _item(
                    context,
                    icon:
                        Icons.people_outline,
                    selectedIcon:
                        Icons.people,
                    title: 'Customers',
                    section:
                        AdminSection.customers,
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  _sectionLabel(
                    'OPERATIONS',
                  ),

                  _item(
                    context,
                    icon:
                        Icons.calendar_month_outlined,
                    selectedIcon:
                        Icons.calendar_month,
                    title: 'Bookings',
                    section:
                        AdminSection.bookings,
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  _sectionLabel(
                    'SYSTEM',
                  ),

                  _item(
                    context,
                    icon:
                        Icons.settings_outlined,
                    selectedIcon:
                        Icons.settings,
                    title: 'Settings',
                    section:
                        AdminSection.settings,
                  ),
                ],
              ),
            ),

            const Divider(
              height: 1,
            ),

            _footer(context),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _header(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        18,
        20,
        18,
        12,
      ),

      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,

            decoration:
                BoxDecoration(
              color:
                  Theme.of(context)
                      .colorScheme
                      .primaryContainer,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),

            child: Icon(
              Icons
                  .admin_panel_settings_outlined,
              color:
                  Theme.of(context)
                      .colorScheme
                      .onPrimaryContainer,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'EVENTOR',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),

                SizedBox(
                  height: 2,
                ),

                Text(
                  'Admin Panel',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION LABEL
  // ===========================================================================

  Widget _sectionLabel(
    String title,
  ) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        12,
        10,
        12,
        6,
      ),

      child: Text(
        title,
        style:
            const TextStyle(
          fontSize: 10,
          fontWeight:
              FontWeight.w700,
          letterSpacing: 1.2,
          color: Colors.grey,
        ),
      ),
    );
  }

  // ===========================================================================
  // ITEM
  // ===========================================================================

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required IconData selectedIcon,
    required String title,
    required AdminSection section,
  }) {
    final selected =
        currentSection == section;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 2,
      ),

      child: Material(
        color: selected
            ? Theme.of(context)
                .colorScheme
                .primaryContainer
            : Colors.transparent,

        borderRadius:
            BorderRadius.circular(
          10,
        ),

        child: InkWell(
          borderRadius:
              BorderRadius.circular(
            10,
          ),

          onTap: () {
            onSectionSelected(
              section,
            );
          },

          child: Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),

            child: Row(
              children: [
                Icon(
                  selected
                      ? selectedIcon
                      : icon,
                  size: 20,
                  color: selected
                      ? Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer
                      : Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child: Text(
                    title,
                    style:
                        TextStyle(
                      fontSize: 14,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: selected
                          ? Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // FOOTER
  // ===========================================================================

  Widget _footer(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.all(12),

      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            child: Icon(
              Icons.person_outline,
              size: 20,
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Administrator',
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight.w600,
                    fontSize: 13,
                  ),
                ),

                SizedBox(
                  height: 2,
                ),

                Text(
                  'Admin Account',
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            tooltip: 'Logout',
            onPressed: () {},
            icon: const Icon(
              Icons.logout_outlined,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}