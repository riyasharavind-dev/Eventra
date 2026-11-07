import 'package:flutter/material.dart';

import '../../models/admin_module.dart';
import '../../widgets/admin_module_card.dart';

class AdminWorkspaceScreen extends StatefulWidget {
  final bool isOwner;
  final List<AdminModule> modules;
  final bool Function(String) canWrite;
  final void Function(String, Map<String, dynamic>) onOpen;
  const AdminWorkspaceScreen({
    super.key,
    required this.modules,
    this.isOwner = false,
    required this.canWrite,
    required this.onOpen,
  });
  @override
  State<AdminWorkspaceScreen> createState() => _AdminWorkspaceScreenState();
}

class _AdminWorkspaceScreenState extends State<AdminWorkspaceScreen> {
  String query = '', section = 'All', capability = 'All access';
  @override
  Widget build(BuildContext context) {
    final sections = widget.modules.map((m) => m.section).toSet().toList()
      ..sort();
    final filtered = widget.modules.where((m) {
      final text = '${m.label} ${m.name} ${m.description}'.toLowerCase();
      return text.contains(query.toLowerCase()) &&
          (section == 'All' || m.section == section) &&
          switch (capability) {
            'Create' => m.canCreate && widget.canWrite(m.name),
            'Edit' => m.editable.isNotEmpty && widget.canWrite(m.name),
            'Delete' => m.canDelete,
            'Workflow' => m.actions.isNotEmpty,
            'Read only' =>
              m.managementMode == 'history' || m.managementMode == 'published',
            _ => true,
          };
    }).toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Manage Eventor',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'One workspace for accounts, services, bookings, content and platform operations.',
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _summary(
              'App modules',
              '${widget.modules.length}',
              Icons.hub_outlined,
            ),
            _summary(
              'Workspaces',
              '${sections.length}',
              Icons.space_dashboard_outlined,
            ),
            _summary(
              'Create enabled',
              '${widget.modules.where((m) => m.canCreate && widget.canWrite(m.name)).length}',
              Icons.add_circle_outline,
            ),
            _summary(
              'Workflow modules',
              '${widget.modules.where((m) => m.actions.isNotEmpty).length}',
              Icons.task_alt,
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (widget.isOwner)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () => widget.onOpen('database_connections', {}),
                  icon: const Icon(Icons.hub_outlined),
                  label: const Text('Database & system tables'),
                ),
                OutlinedButton.icon(
                  onPressed: () => widget.onOpen('storage_buckets', {}),
                  icon: const Icon(Icons.cloud_outlined),
                  label: const Text('Storage buckets'),
                ),
                OutlinedButton.icon(
                  onPressed: () => widget.onOpen('team_access', {}),
                  icon: const Icon(Icons.group_outlined),
                  label: const Text('Team & Access'),
                ),
              ],
            ),
          ),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search modules, tables or operations…',
          ),
          onChanged: (v) => setState(() => query = v),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['All', ...sections]
              .map(
                (s) => ChoiceChip(
                  label: Text(s),
                  selected: section == s,
                  onSelected: (_) => setState(() => section = s),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                '${filtered.length} modules',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SizedBox(
              width: 170,
              child: DropdownButtonFormField<String>(
                initialValue: capability,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Operation',
                ),
                items:
                    [
                          'All access',
                          'Create',
                          'Edit',
                          'Delete',
                          'Workflow',
                          'Read only',
                        ]
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                onChanged: (v) => setState(() => capability = v!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No modules match your search.')),
          ),
        LayoutBuilder(
          builder: (context, size) {
            final columns = size.maxWidth >= 1120
                ? 3
                : size.maxWidth >= 650
                ? 2
                : 1;
            final width = (size.maxWidth - (columns - 1) * 16) / columns;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: filtered
                  .map(
                    (m) => SizedBox(
                      width: width,
                      child: AdminModuleCard(
                        module: m,
                        writable: widget.canWrite(m.name),
                        onOpen: () => widget.onOpen(m.name, {}),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _summary(String label, String value, IconData icon) => SizedBox(
    width: MediaQuery.sizeOf(context).width < 650
        ? (MediaQuery.sizeOf(context).width - 60) / 2
        : 205,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(label, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
