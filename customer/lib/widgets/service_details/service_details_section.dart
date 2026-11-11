import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:flutter/material.dart';

import '../../models/service_model.dart';
import 'service_detail_row.dart';

class ServiceDetailsSection extends StatelessWidget {
  final ServiceModel service;

  const ServiceDetailsSection({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppSettingsScope.translate(
              context,
              "customer.service_details.3028f307",
            ),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF17171B),
            ),
          ),

          const SizedBox(height: 16),

          // ====================================================
          // CATEGORY
          // ====================================================
          ServiceDetailRow(
            icon: Icons.category_outlined,
            title: AppSettingsScope.translate(
              context,
              "customer.category.292c06f0",
            ),
            value: service.categoryName ?? 'Not specified',
          ),

          const Divider(height: 24, color: Color(0xFFF0EDF0)),

          // ====================================================
          // PRICE
          // ====================================================
          ServiceDetailRow(
            icon: Icons.currency_rupee,
            title: AppSettingsScope.translate(
              context,
              "customer.price.93c91c85",
            ),
            value: '₹${service.price.toStringAsFixed(0)}',
          ),

          const Divider(height: 24, color: Color(0xFFF0EDF0)),

          // ====================================================
          // STATUS
          // ====================================================
          ServiceDetailRow(
            icon: Icons.verified_outlined,
            title: AppSettingsScope.translate(
              context,
              "customer.status.920e413c",
            ),
            value: service.isActive ? 'Available' : 'Currently unavailable',
          ),

          const Divider(height: 24, color: Color(0xFFF0EDF0)),

          // ====================================================
          // SERVICE ID
          // ====================================================
          ServiceDetailRow(
            icon: Icons.tag_outlined,
            title: AppSettingsScope.translate(
              context,
              "customer.service_id.a4bd8b91",
            ),
            value: service.id,
          ),
        ],
      ),
    );
  }
}
