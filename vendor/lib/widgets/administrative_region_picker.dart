import 'package:flutter/material.dart';

import '../models/administrative_region.dart';

class AdministrativeRegionPicker extends StatefulWidget {
  final List<AdministrativeRegion> regions;
  final String title;
  final String? selectedId;
  const AdministrativeRegionPicker({
    super.key,
    required this.regions,
    required this.title,
    this.selectedId,
  });
  @override
  State<AdministrativeRegionPicker> createState() =>
      _AdministrativeRegionPickerState();
}

class _AdministrativeRegionPickerState
    extends State<AdministrativeRegionPicker> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final rows = widget.regions
        .where((r) => r.name.toLowerCase().contains(query.trim().toLowerCase()))
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Text(
                      'No matching location. Contact Eventra support if yours is missing.',
                    ),
                  )
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (_, i) => ListTile(
                      title: Text(rows[i].name),
                      trailing: rows[i].id == widget.selectedId
                          ? const Icon(
                              Icons.check_circle,
                              color: Color(0xFF80152C),
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(context, rows[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
