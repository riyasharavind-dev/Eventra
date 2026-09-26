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
  Widget build(
    BuildContext context,
  ) {
    return Card(
      clipBehavior:
          Clip.antiAlias,
      elevation: 1.5,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ====================================================
          // IMAGE
          // ====================================================

          AspectRatio(
            aspectRatio: 16 / 9,
            child: _buildImage(),
          ),

          // ====================================================
          // DETAILS
          // ====================================================

          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                10,
                8,
                8,
                8,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // ============================================
                  // CATEGORY + MENU
                  // ============================================

                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          service.categoryName ??
                              'Uncategorized',
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                Colors.grey.shade600,
                            fontWeight:
                                FontWeight.w500,
                          ),
                        ),
                      ),

                      SizedBox(
                        width: 30,
                        height: 30,
                        child:
                            PopupMenuButton<
                                String>(
                          padding:
                              EdgeInsets.zero,
                          iconSize: 20,
                          onSelected:
                              (
                            String value,
                          ) {
                            switch (value) {
                              case 'toggle':
                                onToggleStatus
                                    ?.call();
                                break;

                              case 'delete':
                                onDelete
                                    ?.call();
                                break;
                            }
                          },
                          itemBuilder:
                              (
                            BuildContext
                                context,
                          ) {
                            return [
                              PopupMenuItem<
                                  String>(
                                value:
                                    'toggle',
                                child: Row(
                                  children: [
                                    Icon(
                                      service
                                              .isActive
                                          ? Icons
                                              .visibility_off_outlined
                                          : Icons
                                              .visibility_outlined,
                                      size: 20,
                                    ),
                                    const SizedBox(
                                      width: 10,
                                    ),
                                    Text(
                                      service
                                              .isActive
                                          ? 'Deactivate'
                                          : 'Activate',
                                    ),
                                  ],
                                ),
                              ),

                              const PopupMenuDivider(),

                              const PopupMenuItem<
                                  String>(
                                value:
                                    'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons
                                          .delete_outline,
                                      size: 20,
                                      color:
                                          Colors.red,
                                    ),
                                    SizedBox(
                                      width: 10,
                                    ),
                                    Text(
                                      'Delete',
                                      style:
                                          TextStyle(
                                        color:
                                            Colors.red,
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

                  const SizedBox(
                    height: 2,
                  ),

                  // ==========================================
                  // NAME
                  // ==========================================

                  Text(
                    service.name,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 14,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                  // ==========================================
                  // DESCRIPTION
                  // ==========================================

                  if (service.description !=
                          null &&
                      service.description!
                          .trim()
                          .isNotEmpty) ...[
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
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
                  ],

                  const Spacer(),

                  // ==========================================
                  // PRICE + STATUS
                  // ==========================================

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '₹${service.price.toStringAsFixed(0)}',
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              const TextStyle(
                            fontSize: 15,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ),

                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              service.isActive
                                  ? Colors
                                      .green
                                      .withValues(
                                      alpha:
                                          0.10,
                                    )
                                  : Colors
                                      .red
                                      .withValues(
                                      alpha:
                                          0.10,
                                    ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            20,
                          ),
                        ),
                        child: Text(
                          service.isActive
                              ? 'Active'
                              : 'Inactive',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight:
                                FontWeight.w700,
                            color:
                                service.isActive
                                    ? Colors.green
                                    : Colors.red,
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

  // ============================================================
  // IMAGE
  // ============================================================

  Widget _buildImage() {
    if (service.gallery.isEmpty) {
      return Container(
        color:
            Colors.grey.shade200,
        child: const Center(
          child: Icon(
            Icons.image_outlined,
            size: 40,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Image.network(
      service.gallery.first,
      fit: BoxFit.cover,
      errorBuilder:
          (
        BuildContext context,
        Object error,
        StackTrace? stackTrace,
      ) {
        return Container(
          color:
              Colors.grey.shade200,
          child: const Center(
            child: Icon(
              Icons
                  .broken_image_outlined,
              size: 40,
              color: Colors.grey,
            ),
          ),
        );
      },
      loadingBuilder:
          (
        BuildContext context,
        Widget child,
        ImageChunkEvent?
            loadingProgress,
      ) {
        if (loadingProgress ==
            null) {
          return child;
        }

        return Container(
          color:
              Colors.grey.shade100,
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child:
                  CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          ),
        );
      },
    );
  }
}