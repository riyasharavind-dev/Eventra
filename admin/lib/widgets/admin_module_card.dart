import 'package:flutter/material.dart';

import '../models/admin_module.dart';

IconData adminSectionIcon(String section) => switch (section) {
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
  _ => Icons.settings_outlined,
};

class AdminCapabilityChips extends StatelessWidget {
  final AdminModule module;
  final bool writable;
  const AdminCapabilityChips({
    super.key,
    required this.module,
    this.writable = true,
  });
  @override
  Widget build(BuildContext context) {
    final labels = [
      'View',
      if (writable && module.canCreate) 'Create',
      if (writable && module.editable.isNotEmpty) 'Edit',
      if (module.canDelete) 'Delete · Owner',
      if (writable && module.actions.isNotEmpty) 'Workflow',
      if (module.managementMode == 'history' ||
          module.managementMode == 'published')
        'Read only',
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: labels
          .map(
            (label) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class AdminModuleCard extends StatelessWidget {
  final AdminModule module;
  final bool writable;
  final VoidCallback onOpen;
  const AdminModuleCard({
    super.key,
    required this.module,
    required this.onOpen,
    required this.writable,
  });
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  adminSectionIcon(module.section),
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    module.label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_outward, size: 18),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              module.description.isEmpty
                  ? 'Open and manage ${module.label.toLowerCase()}.'
                  : module.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            AdminCapabilityChips(module: module, writable: writable),
          ],
        ),
      ),
    ),
  );
}
