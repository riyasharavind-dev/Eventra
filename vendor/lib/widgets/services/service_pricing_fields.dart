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
    String t(String en, String ta) => settings.text(en, ta);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<ServicePricingType>(
          initialValue: value.type,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: t('Pricing type', 'விலை வகை'),
            border: const OutlineInputBorder(),
          ),
          items: ServicePricingType.values
              .map(
                (type) => DropdownMenuItem(
                  value: type,
                  child: Text(settings.tamil ? type.tamilLabel : type.label),
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
              labelText: t('Unit name', 'அலகின் பெயர்'),
              helperText: t(
                'Example: chair, plate, person, kg, km',
                'உதாரணம்: chair, plate, person, kg, km',
              ),
              border: const OutlineInputBorder(),
            ),
            onChanged: (unit) =>
                onChanged(ServicePricing(type: value.type, unit: unit)),
            validator: (unit) =>
                unit == null || unit.trim().isEmpty || unit.trim().length > 40
                ? t('Enter a unit', 'அலகை உள்ளிடவும்')
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
              labelText: t('Duration unit', 'கால அளவு'),
              border: const OutlineInputBorder(),
            ),
            items: ServicePricing.durationUnits
                .map(
                  (unit) => DropdownMenuItem(
                    value: unit,
                    child: Text(switch (unit) {
                      'hour' => t('Hour', 'மணி'),
                      'day' => t('Day', 'நாள்'),
                      'week' => t('Week', 'வாரம்'),
                      _ => t('Month', 'மாதம்'),
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
          ServicePricingType.fixed => t(
            'The amount is the fixed service price.',
            'இந்தத் தொகை நிலையான சேவை விலை.',
          ),
          ServicePricingType.startingFrom => t(
            'The amount is a starting price. Final price depends on requirements.',
            'இது ஆரம்ப விலை. தேவைகளைப் பொறுத்து இறுதி விலை மாறும்.',
          ),
          ServicePricingType.perUnit => t(
            'Enter the price for one unit below.',
            'கீழே ஒரு அலகிற்கான விலையை உள்ளிடவும்.',
          ),
          ServicePricingType.perDuration => t(
            'Enter the price for one selected duration below.',
            'தேர்ந்தெடுத்த ஒரு கால அளவிற்கான விலையை உள்ளிடவும்.',
          ),
        }, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
      ],
    );
  }
}
