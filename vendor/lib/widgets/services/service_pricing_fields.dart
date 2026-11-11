import 'package:flutter/material.dart';

import '../../models/service_pricing.dart';
import '../../services/app_settings_controller.dart';

class ServicePricingFields extends StatelessWidget {
  const ServicePricingFields({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });
  final ServicePricing value;
  final ValueChanged<ServicePricing> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<ServicePricingType>(
          initialValue: value.type,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: AppSettingsScope.translate(
              context,
              "vendor.pricing_type.5e1b131a",
            ),
            border: const OutlineInputBorder(),
          ),
          items: ServicePricingType.values
              .map(
                (type) => DropdownMenuItem(
                  value: type,
                  child: Text(settings.text(type.label)),
                ),
              )
              .toList(),
          onChanged: enabled
              ? (type) {
                  if (type == null) return;
                  onChanged(
                    ServicePricing(
                      type: type,
                      unit: type == value.type
                          ? value.unit
                          : type == ServicePricingType.perDuration
                          ? 'hour'
                          : type == ServicePricingType.perUnit
                          ? 'item'
                          : null,
                    ),
                  );
                }
              : null,
        ),
        const SizedBox(height: 12),
        if (value.type == ServicePricingType.perUnit) ...[
          TextFormField(
            key: const ValueKey('pricing-unit'),
            initialValue: value.unit,
            enabled: enabled,
            maxLength: 40,
            decoration: InputDecoration(
              labelText: AppSettingsScope.translate(
                context,
                "vendor.unit_name.a1cc787b",
              ),
              helperText: AppSettingsScope.translate(
                context,
                "vendor.example_chair_plate_person_kg_km.c26afcad",
              ),
              border: const OutlineInputBorder(),
            ),
            onChanged: (unit) =>
                onChanged(ServicePricing(type: value.type, unit: unit)),
            validator: (unit) =>
                unit == null || unit.trim().isEmpty || unit.trim().length > 40
                ? AppSettingsScope.translate(
                    context,
                    "vendor.enter_a_unit.c1415246",
                  )
                : null,
          ),
          const SizedBox(height: 12),
        ],
        if (value.type == ServicePricingType.perDuration) ...[
          DropdownButtonFormField<String>(
            initialValue: ServicePricing.durationUnits.contains(value.unit)
                ? value.unit
                : 'hour',
            decoration: InputDecoration(
              labelText: AppSettingsScope.translate(
                context,
                "vendor.duration_unit.7ba318fe",
              ),
              border: const OutlineInputBorder(),
            ),
            items: ServicePricing.durationUnits
                .map(
                  (unit) => DropdownMenuItem(
                    value: unit,
                    child: Text(switch (unit) {
                      'hour' => AppSettingsScope.translate(
                        context,
                        "vendor.hour.f0063b80",
                      ),
                      'day' => AppSettingsScope.translate(
                        context,
                        "vendor.day.8f2364e1",
                      ),
                      'week' => AppSettingsScope.translate(
                        context,
                        "vendor.week.e78041ab",
                      ),
                      _ => AppSettingsScope.translate(
                        context,
                        "vendor.month.310ca503",
                      ),
                    }),
                  ),
                )
                .toList(),
            onChanged: enabled
                ? (unit) =>
                      onChanged(ServicePricing(type: value.type, unit: unit))
                : null,
          ),
          const SizedBox(height: 12),
        ],
        Text(switch (value.type) {
          ServicePricingType.fixed => AppSettingsScope.translate(
            context,
            "vendor.the_amount_is_the_fixed_service_price.8e4eea7b",
          ),
          ServicePricingType.startingFrom => AppSettingsScope.translate(
            context,
            "vendor.the_amount_is_a_starting_price_final_price_de.f6e2a51a",
          ),
          ServicePricingType.perUnit => AppSettingsScope.translate(
            context,
            "vendor.enter_the_price_for_one_unit_below.184d2e62",
          ),
          ServicePricingType.perDuration => AppSettingsScope.translate(
            context,
            "vendor.enter_the_price_for_one_selected_duration_bel.110b00a2",
          ),
        }, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
      ],
    );
  }
}
