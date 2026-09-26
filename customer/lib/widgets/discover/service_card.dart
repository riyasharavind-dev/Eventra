import 'package:flutter/material.dart';

import '../../models/service_model.dart';
import 'service_gallery.dart';

class ServiceCard extends StatelessWidget {
  // ============================================================
  // SERVICE DATA
  // ============================================================

  final ServiceModel service;

  // ============================================================
  // CALLBACK
  // ============================================================

  final VoidCallback? onView;

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  const ServiceCard({
    super.key,
    required this.service,
    this.onView,
  });

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.04,
                ),
                blurRadius: 8,
                offset: const Offset(
                  0,
                  3,
                ),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // ==================================================
                // SERVICE IMAGE
                // ==================================================

                AspectRatio(
                  aspectRatio: 1.22,
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(12),
                    child: ServiceGallery(
                      gallery: service.gallery,
                      height: double.infinity,
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ==================================================
                // CATEGORY
                // ==================================================

                Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 5,
                  ),
                  child: Text(
                    service.categoryName ??
                        'Service',
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w600,
                      color: Theme.of(context)
                          .colorScheme
                          .primary,
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // ==================================================
                // SERVICE NAME
                // ==================================================

                Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 5,
                  ),
                  child: Text(
                    service.name,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight:
                          FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),

                // ==================================================
                // DESCRIPTION
                // ==================================================

                if (service.description != null &&
                    service.description!
                        .trim()
                        .isNotEmpty) ...[
                  const SizedBox(height: 5),

                  Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 5,
                    ),
                    child: Text(
                      service.description!,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            Colors.grey.shade600,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],

                const Spacer(),

                // ==================================================
                // PRICE
                // ==================================================

                Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 5,
                  ),
                  child: Text(
                    '₹${service.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),

                const SizedBox(height: 7),
              ],
            ),
          ),
        ),
      ),
    );
  }
}