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

  Widget _summary(String label, String value, IconData icon) => Container(
    width: MediaQuery.sizeOf(context).width < 650
        ? (MediaQuery.sizeOf(context).width - 60) / 2
        : 210,
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
    padding: const EdgeInsets.all(18),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF5E8EC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF80152C), size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF17171B),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF73737D),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

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
        // Title Header
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Control Centre',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF17171B),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Unified registry of modules, databases, workflows, and platform operations.',
                    style: TextStyle(fontSize: 13.5, color: Color(0xFF73737D)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Summary Statistics Cards
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _summary(
              'Active modules',
              '${widget.modules.length}',
              Icons.hub_outlined,
            ),
            _summary(
              'Domain sections',
              '${sections.length}',
              Icons.space_dashboard_outlined,
            ),
            _summary(
              'Create enabled',
              '${widget.modules.where((m) => m.canCreate && widget.canWrite(m.name)).length}',
              Icons.add_circle_outline,
            ),
            _summary(
              'Workflow enabled',
              '${widget.modules.where((m) => m.actions.isNotEmpty).length}',
              Icons.task_alt,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Owner Shortcuts Bar
        if (widget.isOwner)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF0EDF0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OWNER INFRASTRUCTURE CONTROLS',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: Color(0xFF80152C),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => widget.onOpen('database_connections', {}),
                        icon: const Icon(Icons.hub_outlined, size: 18),
                        label: const Text('Database & System Tables'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => widget.onOpen('storage_buckets', {}),
                        icon: const Icon(Icons.cloud_outlined, size: 18),
                        label: const Text('Storage Buckets'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => widget.onOpen('team_access', {}),
                        icon: const Icon(Icons.group_outlined, size: 18),
                        label: const Text('Team & Permissions'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        // Search & Filter Controls
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search, color: Color(0xFF73737D)),
            hintText: 'Search modules by name, section, or description…',
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => query = ''),
                  )
                : null,
          ),
          onChanged: (v) => setState(() => query = v),
        ),
        const SizedBox(height: 16),

        // Section Choice Chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['All', ...sections].map((s) {
            final isSelected = section == s;
            return ChoiceChip(
              label: Text(s),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: const Color(0xFFF5E8EC),
              backgroundColor: Colors.white,
              side: BorderSide(
                color: isSelected ? const Color(0xFF80152C) : const Color(0xFFF0EDF0),
              ),
              labelStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF80152C) : const Color(0xFF17171B),
              ),
              onSelected: (_) => setState(() => section = s),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Capabilities Filter & Count Row
        Row(
          children: [
            Expanded(
              child: Text(
                'Showing ${filtered.length} modules',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF17171B),
                ),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: capability,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Access Capability',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: [
                  'All access',
                  'Create',
                  'Edit',
                  'Delete',
                  'Workflow',
                  'Read only',
                ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) => setState(() => capability = v!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(48),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.search_off_rounded, size: 48, color: Color(0xFFA0A0AC)),
                  SizedBox(height: 12),
                  Text(
                    'No modules match your current filter.',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF73737D),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Module Cards Grid
        LayoutBuilder(
          builder: (context, size) {
            final columns = size.maxWidth >= 1150
                ? 3
                : size.maxWidth >= 680
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
}
