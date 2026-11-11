import 'package:eventor_vendor/services/app_settings_controller.dart';
import 'package:eventor_vendor/core/theme/app_icon_colors.dart';
import 'package:flutter/material.dart';

import '../../models/business_model.dart';

/// Matches the compact, horizontal service cards without changing business flows.
class BusinessListCard extends StatelessWidget {
  final BusinessModel business;
  final VoidCallback onOpen;
  final Widget rating;
  const BusinessListCard({
    super.key,
    required this.business,
    required this.onOpen,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    final address = (business.shopAddress ?? business.address ?? '').trim();
    final description = business.description?.trim() ?? '';
    final image = [
      business.bannerUrl,
      business.logoUrl,
    ].whereType<String>().where((url) => url.trim().isNotEmpty).firstOrNull;
    const muted = Color(0xFF73737D);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0EDF0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF80152C).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth < 320 ? 86.0 : 102.0;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: SizedBox(
                        width: width,
                        height: 114,
                        child: image == null
                            ? const _BusinessPhotoFallback()
                            : Image.network(
                                image,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const _BusinessPhotoFallback(),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              business.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF17171B),
                              ),
                            ),
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: muted,
                              ),
                            ),
                          ],
                          if (address.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: AppIconColors.standard,
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    address,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          rating,
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      height: 40,
                      child: IconButton(
                        onPressed: onOpen,
                        tooltip: AppSettingsScope.translate(
                          context,
                          "vendor.view_business.71b97e44",
                        ),
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.chevron_right_rounded,
                          size: 22,
                          color: AppIconColors.standard,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BusinessPhotoFallback extends StatelessWidget {
  const _BusinessPhotoFallback();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFF5E8EC),
    child: Center(
      child: Icon(
        Icons.storefront_outlined,
        color: AppIconColors.standard,
        size: 32,
      ),
    ),
  );
}
