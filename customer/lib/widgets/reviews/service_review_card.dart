import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:flutter/material.dart';

import '../../models/service_review_model.dart';

class ReviewPhotoStrip extends StatelessWidget {
  const ReviewPhotoStrip({super.key, required this.urls});
  final List<String> urls;
  @override
  Widget build(BuildContext context) => urls.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 10),
          child: SizedBox(
            height: 74,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: urls.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (context) => Dialog(
                    backgroundColor: Colors.black,
                    child: Stack(
                      children: [
                        InteractiveViewer(
                          child: Image.network(
                            urls[i],
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Padding(
                              padding: const EdgeInsets.all(40),
                              child: Text(
                                AppSettingsScope.translate(
                                  context,
                                  "customer.photo_expired_close_and_refresh_reviews.9f733ade",
                                ),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            tooltip: AppSettingsScope.translate(
                              context,
                              "customer.close_photo.0a040c7f",
                            ),
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    urls[i],
                    width: 90,
                    height: 74,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 90,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
}

class ServiceReviewCard extends StatelessWidget {
  const ServiceReviewCard({super.key, required this.review, this.onRatingTap});
  final ServiceReviewModel review;
  final VoidCallback? onRatingTap;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFF0EDF0)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF80152C).withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFF5E8EC),
              child: Icon(
                Icons.person_outline,
                color: Color(0xFF80152C),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.customerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF17171B),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    MaterialLocalizations.of(context)
                        .formatShortDate(review.createdAt.toLocal()),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF73737D),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: onRatingTap,
          borderRadius: BorderRadius.circular(6),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                Icon(
                  i <= review.rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 18,
                  color: const Color(0xFFFFCB48),
                ),
              const SizedBox(width: 6),
              Text(
                '${review.rating}/5',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF73737D),
                ),
              ),
            ],
          ),
        ),
        if (review.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              review.text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Color(0xFF17171B),
              ),
            ),
          ),
        ReviewPhotoStrip(urls: review.photoUrls),
      ],
    ),
  );
}
