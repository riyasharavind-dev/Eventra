import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:flutter/material.dart';

import '../../models/service_review_model.dart';

class ReviewRatingSummary extends StatelessWidget {
  const ReviewRatingSummary({
    super.key,
    required this.summary,
    this.selectedRating,
    this.onRatingSelected,
  });
  final ReviewSummary summary;
  final int? selectedRating;
  final ValueChanged<int>? onRatingSelected;
  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0EDF0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF80152C).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                summary.average == null || summary.average == 0
                    ? '0'
                    : summary.average!.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 32,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF202024),
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                '/ 5',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF777783),
                ),
              ),
              const SizedBox(width: 9),
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFFFCB48),
                size: 23,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppSettingsScope.translate(
              context,
              "customer.value0_public_value1.1e685019",
              args: {
                "value0": summary.count,
                "value1": summary.count == 1 ? 'review' : 'reviews',
              },
            ),
            style: const TextStyle(fontSize: 12, color: Color(0xFF777783)),
          ),
          const SizedBox(height: 20),
          for (var stars = 5; stars >= 1; stars--)
            Material(
              color: selectedRating == stars
                  ? const Color(0xFFF9EDF2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onRatingSelected == null
                    ? null
                    : () => onRatingSelected!(stars),
                child: Padding(
                  padding: EdgeInsets.only(bottom: stars == 1 ? 0 : 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32 * scale,
                        child: Row(
                          children: [
                            Text(
                              '$stars',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF625D68),
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFFFCB48),
                              size: 12,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: summary.count == 0
                              ? 0
                              : ((summary.stars[stars] ?? 0) / summary.count)
                                    .clamp(0.0, 1.0),
                          minHeight: 7,
                          borderRadius: BorderRadius.circular(8),
                          backgroundColor: const Color(0xFFF3F1F4),
                          color: const Color(0xFF80152C),
                          semanticsLabel:
                              '$stars stars, ${summary.stars[stars] ?? 0} reviews',
                        ),
                      ),
                      const SizedBox(width: 9),
                      SizedBox(
                        width: 25 * scale,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${summary.stars[stars] ?? 0}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF777783),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
