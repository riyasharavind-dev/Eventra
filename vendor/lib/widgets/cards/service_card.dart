import 'package:eventor_vendor/services/app_settings_controller.dart';
import 'package:eventor_vendor/core/theme/app_icon_colors.dart';

import '../common/app_shimmer.dart';

import 'package:flutter/material.dart';

import '../../models/service_model.dart';

class ServiceCard extends StatelessWidget {
  final ServiceModel service;

  final VoidCallback? onToggleStatus;
  final VoidCallback? onDelete;

  const ServiceCard({
    super.key,
    required this.service,
    this.onToggleStatus,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0EDF0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF80152C).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(aspectRatio: 16 / 9, child: _buildImage()),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          service.categoryName ?? 'Uncategorized',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF73737D),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          onSelected: (String value) {
                            switch (value) {
                              case 'toggle':
                                onToggleStatus?.call();
                                break;
                              case 'delete':
                                onDelete?.call();
                                break;
                            }
                          },
                          itemBuilder: (BuildContext context) {
                            return [
                              PopupMenuItem<String>(
                                value: 'toggle',
                                child: Row(
                                  children: [
                                    Icon(
                                      service.isActive
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 18,
                                      color: AppIconColors.standard,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      service.isActive
                                          ? 'Deactivate'
                                          : 'Activate',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: Color(0xFFC62828),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      AppSettingsScope.translate(
                                        context,
                                        "vendor.delete.e2d0a549",
                                      ),
                                      style: TextStyle(
                                        color: Color(0xFFC62828),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ];
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    service.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF17171B),
                    ),
                  ),
                  if (service.description != null &&
                      service.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      service.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF73737D),
                        height: 1.25,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          service.priceLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF80152C),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: service.isActive
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFF5E8EC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          service.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: service.isActive
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFF80152C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (service.gallery.isEmpty) {
      return Container(
        color: const Color(0xFFF5E8EC),
        child: const Center(
          child: Icon(
            Icons.image_outlined,
            size: 36,
            color: AppIconColors.standard,
          ),
        ),
      );
    }

    return Image.network(
      service.gallery.first,
      fit: BoxFit.cover,
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) {
            return Container(
              color: const Color(0xFFF5E8EC),
              child: const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 36,
                  color: AppIconColors.standard,
                ),
              ),
            );
          },
      loadingBuilder:
          (
            BuildContext context,
            Widget child,
            ImageChunkEvent? loadingProgress,
          ) {
            if (loadingProgress == null) {
              return child;
            }

            return Container(
              color: const Color(0xFFF5E8EC),
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: AppShimmerIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF80152C),
                  ),
                ),
              ),
            );
          },
    );
  }
}
