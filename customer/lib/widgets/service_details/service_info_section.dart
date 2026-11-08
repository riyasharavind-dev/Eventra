import 'package:flutter/material.dart';

import '../../models/service_model.dart';

class ServiceInfoSection extends StatelessWidget {
  final ServiceModel service;

  const ServiceInfoSection({
    super.key,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(
        top: 8,
      ),
      padding: const EdgeInsets.fromLTRB(
        16,
        18,
        16,
        18,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ====================================================
          // CATEGORY
          // ====================================================

          if (service.categoryName != null &&
              service.categoryName!
                  .trim()
                  .isNotEmpty)
            Text(
              service.categoryName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Theme.of(context)
                    .colorScheme
                    .primary,
              ),
            ),

          const SizedBox(height: 8),

          // ====================================================
          // SERVICE NAME
          // ====================================================

          Text(
            service.name,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),

          const SizedBox(height: 14),

          // ====================================================
          // PRICE
          // ====================================================

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              Text(
                '₹${service.price.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(
                  bottom: 4,
                ),
                child: Text(
                  'starting price',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ====================================================
          // AVAILABILITY
          // ====================================================

          if (service.isActive)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius:
                    BorderRadius.circular(5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 15,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Available',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}