import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:flutter/material.dart';

import '../../models/service_model.dart';
import '../../models/service_pricing.dart';

class ServicePriceSummary extends StatelessWidget {
  const ServicePriceSummary({
    super.key,
    required this.service,
    required this.overview,
  });
  final ServiceModel service;
  final Map<String, dynamic> overview;
  @override
  Widget build(BuildContext context) {
    final current = (overview['price'] as num?)?.toDouble() ?? service.price;
    final pricing = overview.containsKey('pricing_type')
        ? ServicePricing.fromMap(overview)
        : service.pricing;
    final previous = (overview['previous_price'] as num?)?.toDouble();
    final oldPricing = ServicePricing.fromMap({
      'pricing_type': overview['previous_pricing_type'],
      'pricing_unit': overview['previous_pricing_unit'],
    });
    final comparable =
        oldPricing.type == pricing.type && oldPricing.unit == pricing.unit;
    final percentage = previous != null && previous > 0 && comparable
        ? (current - previous) / previous * 100
        : null;
    final decreased = percentage != null && percentage < 0;
    final label = percentage == null
        ? (comparable ? 'Price updated' : 'Pricing basis changed')
        : percentage == 0
        ? 'Price unchanged'
        : '${percentage.abs().toStringAsFixed(1)}% ${decreased ? 'decrease' : 'increase'}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pricing.format(current),
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            color: Color(0xFF80152C),
          ),
        ),
        if (previous != null) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 9,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                AppSettingsScope.translate(
                  context,
                  "customer.previously_value0.279cb152",
                  args: {"value0": oldPricing.format(previous)},
                ),
                style: const TextStyle(fontSize: 13, color: Color(0xFF73737D)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: decreased
                      ? const Color(0xFFE8F5EA)
                      : const Color(0xFFF9EDEF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: decreased
                        ? const Color(0xFF24733B)
                        : const Color(0xFF80152C),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
