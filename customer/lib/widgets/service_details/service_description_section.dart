import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:flutter/material.dart';

import '../../models/service_model.dart';

class ServiceDescriptionSection extends StatelessWidget {
  const ServiceDescriptionSection({super.key, required this.service});
  final ServiceModel service;

  @override
  Widget build(BuildContext context) {
    final description = service.description?.trim() ?? '';
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppSettingsScope.translate(
              context,
              "customer.about_this_service.58830b1a",
            ),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF17171B),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            description.isEmpty ? 'No description added yet.' : description,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF73737D),
            ),
          ),
        ],
      ),
    );
  }
}
