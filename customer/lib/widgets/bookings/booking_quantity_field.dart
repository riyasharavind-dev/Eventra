import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:flutter/material.dart';

import '../../models/service_model.dart';
import '../../models/service_pricing.dart';

class BookingQuantityField extends StatelessWidget {
  const BookingQuantityField({
    super.key,
    required this.service,
    required this.onChanged,
    this.initialValue = 1,
    this.enabled = true,
  });
  final ServiceModel service;
  final ValueChanged<int> onChanged;
  final int initialValue;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextFormField(
      initialValue: '$initialValue',
      enabled: enabled,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText:
            '${service.name} — ${service.pricing.type == ServicePricingType.perDuration ? "Number of" : "Quantity"} ${service.pricing.unit ?? "units"}',
        helperText: service.priceLabel,
      ),
      validator: (value) {
        final n = int.tryParse(value ?? '');
        return n == null || n < 1 || n > 100000
            ? AppSettingsScope.translate(
                context,
                "customer.enter_a_whole_number_from_1_to_100000.1552a7f8",
              )
            : null;
      },
      onChanged: (value) {
        final n = int.tryParse(value);
        if (n != null) onChanged(n);
      },
    ),
  );
}
