import 'package:flutter/material.dart';

import '../../models/admin_module.dart';
import '../../repositories/admin_repository.dart';
import '../management/admin_record_editor.dart';

class AdminCatalogScreen extends StatelessWidget {
  final AdminRepository repo;
  final List<AdminModule> modules;
  final bool Function(String) canWrite;
  final void Function(String, Map<String, dynamic>) onOpen;
  const AdminCatalogScreen({
    super.key,
    required this.repo,
    required this.modules,
    required this.canWrite,
    required this.onOpen,
  });

  Future<void> _create(BuildContext context, AdminModule module) async {
    final result = await Navigator.of(context).push<AdminRecord>(
      MaterialPageRoute(
        builder: (_) =>
            AdminRecordEditor(repo: repo, module: module, modules: modules),
      ),
    );
    if (result != null && context.mounted) onOpen(module.name, {});
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF0EDF0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF80152C).withValues(alpha: 0.03),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Categories & Event Types Studio',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF17171B),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Manage the core marketplace taxonomy shared across vendor onboardings, search indices, and customer discovery.',
              style: TextStyle(fontSize: 13.5, color: Color(0xFF73737D)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      for (final name in ['category_nodes', 'event_types'])
        if (modules.any((m) => m.name == name))
          _card(context, modules.firstWhere((m) => m.name == name)),
    ],
  );

  Widget _card(BuildContext context, AdminModule module) {
    final categories = module.name == 'category_nodes';
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5E8EC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  categories
                      ? Icons.account_tree_outlined
                      : Icons.celebration_outlined,
                  color: const Color(0xFF80152C),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  module.label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF17171B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            categories
                ? 'Create root categories such as Decoration or Photography, then attach nested subcategories. Root categories power vendor business registration, while subcategories drive service listings.'
                : 'Define core event occasions such as Wedding, Birthday, or Corporate Gala. Set visual icons, cover images, and sort orders. Only active types appear publicly.',
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF73737D),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: () => onOpen(module.name, {}),
                icon: const Icon(Icons.list_alt_rounded, size: 18),
                label: Text(
                  categories ? 'Manage Categories' : 'Manage Event Types',
                ),
              ),
              if (module.canCreate && canWrite(module.name))
                FilledButton.icon(
                  onPressed: () => _create(context, module),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(
                    categories ? 'Create Category' : 'Create Event Type',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
