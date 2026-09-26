import 'package:flutter/material.dart';

import '../../models/service_model.dart';
import 'service_detail_row.dart';

class ServiceDetailsSection
    extends StatelessWidget {
  final ServiceModel service;

  const ServiceDetailsSection({
    super.key,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(
        top: 8,
      ),
      padding: const EdgeInsets.fromLTRB(
        16,
        18,
        16,
        20,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Service Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 16),

          // ====================================================
          // CATEGORY
          // ====================================================

          ServiceDetailRow(
            icon: Icons.category_outlined,
            title: 'Category',
            value:
                service.categoryName ??
                    'Not specified',
          ),

          const Divider(
            height: 24,
          ),

          // ====================================================
          // PRICE
          // ====================================================

          ServiceDetailRow(
            icon: Icons.currency_rupee,
            title: 'Price',
            value:
                '₹${service.price.toStringAsFixed(0)}',
          ),

          const Divider(
            height: 24,
          ),

          // ====================================================
          // STATUS
          // ====================================================

          ServiceDetailRow(
            icon: Icons.verified_outlined,
            title: 'Status',
            value: service.isActive
                ? 'Available'
                : 'Currently unavailable',
          ),

          const Divider(
            height: 24,
          ),

          // ====================================================
          // SERVICE ID
          // ====================================================

          ServiceDetailRow(
            icon: Icons.tag_outlined,
            title: 'Service ID',
            value: service.id,
          ),
        ],
      ),
    );
  }
}