import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:flutter/material.dart';

import '../../models/customer_address.dart';

Future<AddressRegion?> selectAddressRegion(
  BuildContext context, {
  required String title,
  required List<AddressRegion> regions,
  String? selectedId,
}) => showModalBottomSheet<AddressRegion>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) {
    String search = '';
    return StatefulBuilder(
      builder: (context, setState) {
        final rows = regions
            .where(
              (r) => r.name.toLowerCase().contains(search.toLowerCase().trim()),
            )
            .toList();
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .7,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    onChanged: (value) => setState(() => search = value),
                    decoration: InputDecoration(
                      hintText: AppSettingsScope.translate(
                        context,
                        "customer.search_location.8ae03735",
                      ),
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  child: rows.isEmpty
                      ? Center(
                          child: Text(
                            AppSettingsScope.translate(
                              context,
                              "customer.no_matching_locations.267dceb0",
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, i) => ListTile(
                            title: Text(rows[i].name),
                            trailing: rows[i].id == selectedId
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF80152C),
                                  )
                                : null,
                            onTap: () => Navigator.pop(context, rows[i]),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  },
);
