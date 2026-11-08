import 'package:eventor_vendor/core/theme/app_icon_colors.dart';

import 'vendor_page_scaffold.dart';

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
    return VendorPageScaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: const Color(0xFFF8F8FA),
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppIconColors.standard,
                ),
                hintText: 'Search location…',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE8E5E8)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE8E5E8)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFF80152C),
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No matching location. Contact Eventor support if yours is missing.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF73737D)),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: rows.length,
                    itemBuilder: (_, i) => Container(
                      key: ValueKey(rows[i].id),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: rows[i].id == widget.selectedId
                              ? const Color(0xFF80152C)
                              : const Color(0xFFF0EDF0),
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          title: Text(
                            rows[i].name,
                            style: TextStyle(
                              fontWeight: rows[i].id == widget.selectedId
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: rows[i].id == widget.selectedId
                                  ? const Color(0xFF80152C)
                                  : const Color(0xFF17171B),
                            ),
                          ),
                          trailing: rows[i].id == widget.selectedId
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF80152C),
                                )
                              : const Icon(
                                  Icons.chevron_right,
                                  color: AppIconColors.standard,
                                ),
                          onTap: () => Navigator.pop(context, rows[i]),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
