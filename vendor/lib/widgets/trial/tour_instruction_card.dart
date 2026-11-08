import 'package:flutter/material.dart';

import '../../models/vendor_tour_step.dart';
import '../../services/app_settings_controller.dart';

class TourInstructionCard extends StatelessWidget {
  const TourInstructionCard({
    super.key,
    required this.step,
    required this.onBack,
  });
  final int step;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final content = VendorTourStep.steps[step];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: 12,
              children: [
                Text(
                  settings.text('Step ${step + 1} of 6', 'படி ${step + 1} / 6'),
                  style: const TextStyle(
                    color: Color(0xFF80152C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (onBack != null)
                  TextButton(
                    onPressed: onBack,
                    child: Text(settings.text('Back', 'முன்பு')),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (step + 1) / 6,
              color: const Color(0xFF80152C),
              backgroundColor: const Color(0xFFECECF0),
              minHeight: 4,
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 16),
            Text(
              settings.text(content.title, content.tamilTitle),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              settings.text(content.body, content.tamilBody),
              style: const TextStyle(height: 1.5, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              settings.text(
                'Tap the highlighted item below',
                'கீழே காட்டப்பட்ட பகுதியைத் தொடவும்',
              ),
              style: const TextStyle(fontSize: 12, color: Color(0xFF73737D)),
            ),
          ],
        ),
      ),
    );
  }
}
