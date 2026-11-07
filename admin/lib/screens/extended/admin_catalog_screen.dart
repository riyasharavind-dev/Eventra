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
      Text(
        'Categories & Event Types',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      const Text(
        'Manage the shared catalog used by the vendor and customer apps. Saved changes are available on their next fetch or refresh.',
      ),
      const SizedBox(height: 24),
      for (final name in ['category_nodes', 'event_types'])
        if (modules.any((m) => m.name == name))
          _card(context, modules.firstWhere((m) => m.name == name)),
    ],
  );

  Widget _card(BuildContext context, AdminModule module) {
    final categories = module.name == 'category_nodes';
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  categories
                      ? Icons.account_tree_outlined
                      : Icons.celebration_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    module.label,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              categories
                  ? 'Create parent categories such as Decoration, then add subcategories such as Stage Decoration by selecting their parent. Leave Parent category empty to create a main category.'
                  : 'Create event types such as Wedding or Birthday. Manage their name, description, icon, image, active status and display order. Only active event types are available through the apps’ public catalog.',
            ),
            const SizedBox(height: 8),
            Text(
              categories
                  ? 'Vendor business selection uses parent categories; service selection and customer Explore use the category hierarchy.'
                  : 'Vendor service creation reads these event types. Customer bookings use the linked event-type records.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () => onOpen(module.name, {}),
                  icon: const Icon(Icons.list_alt),
                  label: Text(
                    categories ? 'Manage Categories' : 'Manage Event Types',
                  ),
                ),
                if (module.canCreate && canWrite(module.name))
                  FilledButton.icon(
                    onPressed: () => _create(context, module),
                    icon: const Icon(Icons.add),
                    label: Text(
                      categories ? 'Create Category' : 'Create Event Type',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
