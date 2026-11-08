import 'package:flutter/material.dart';

import '../../models/service_model.dart';

class ServiceDescriptionSection
    extends StatelessWidget {
  final ServiceModel service;

  const ServiceDescriptionSection({
    super.key,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final String description =
        service.description?.trim() ?? '';

    if (description.isEmpty) {
      return const SizedBox.shrink();
    }

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
            'About this service',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}