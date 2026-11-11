import 'package:eventor_vendor/services/app_settings_controller.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_icon_colors.dart';
import '../../models/service_review_model.dart';

class RecentReviewCard extends StatelessWidget {
  const RecentReviewCard({
    super.key,
    required this.review,
    required this.onOpen,
  });
  final ServiceReviewModel review;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: Color(0xFFF0EDF0)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              review.customerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              review.serviceName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppIconColors.standard,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 17,
                  color: Color(0xFFD49700),
                ),
                const SizedBox(width: 4),
                Text(
                  '${review.rating}/5',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.chevron_right,
                  size: 17,
                  color: AppIconColors.standard,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                review.text.isEmpty
                    ? (AppSettingsScope.translate(
                        context,
                        "vendor.rating_only.770773ab",
                      ))
                    : review.text,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Color(0xFF4E4E59),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
