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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: label == 'Create'
                    ? const Color(0xFFE8F5E9)
                    : label == 'Workflow'
                    ? const Color(0xFFF5E8EC)
                    : const Color(0xFFF8F8FA),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: label == 'Create'
                      ? const Color(0xFFC8E6C9)
                      : label == 'Workflow'
                      ? const Color(0xFFF2D1DC)
                      : const Color(0xFFF0EDF0),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: label == 'Create'
                      ? const Color(0xFF2E7D32)
                      : label == 'Workflow'
                      ? const Color(0xFF80152C)
                      : const Color(0xFF73737D),
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
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFF0EDF0)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF80152C).withValues(alpha: 0.03),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5E8EC),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      adminSectionIcon(module.section),
                      color: const Color(0xFF80152C),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      module.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF17171B),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_outward_rounded,
                    size: 18,
                    color: Color(0xFF80152C),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                module.description.isEmpty
                    ? 'Open and manage ${module.label.toLowerCase()} records.'
                    : module.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF73737D),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              AdminCapabilityChips(module: module, writable: writable),
            ],
          ),
        ),
      ),
    ),
  );
}
