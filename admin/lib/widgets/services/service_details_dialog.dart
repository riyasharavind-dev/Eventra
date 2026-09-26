import 'package:flutter/material.dart';

import '../../models/service_model.dart';

class ServiceDetailsDialog extends StatelessWidget {
  final ServiceModel service;

  const ServiceDetailsDialog({
    super.key,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 700,
          maxHeight: 800,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // ====================================================
              // HEADER
              // ====================================================

              Row(
                children: [
                  Expanded(
                    child: Text(
                      service.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              Text(
                service.slug,
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 20),

              // ====================================================
              // GALLERY
              // ====================================================

              if (service.gallery.isNotEmpty)
                SizedBox(
                  height: 180,
                  child: ListView.separated(
                    scrollDirection:
                        Axis.horizontal,
                    itemCount:
                        service.gallery.length,
                    separatorBuilder:
                        (_, _) =>
                            const SizedBox(width: 12),
                    itemBuilder:
                        (context, index) {
                      return ClipRRect(
                        borderRadius:
                            BorderRadius.circular(12),
                        child: Image.network(
                          service.gallery[index],
                          width: 260,
                          height: 160,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, _, _) {
                            return Container(
                              width: 260,
                              height: 160,
                              color: Colors.grey
                                  .shade200,
                              child: const Icon(
                                Icons
                                    .broken_image_outlined,
                                size: 40,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                )
              else
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color:
                        Colors.grey.shade100,
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'No images',
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // ====================================================
              // BASIC INFORMATION
              // ====================================================

              _sectionTitle(
                context,
                'Service Information',
              ),

              _infoRow(
                'Service Name',
                service.name,
              ),

              _infoRow(
                'Slug',
                service.slug,
              ),

              _infoRow(
                'Price',
                '₹${service.price.toStringAsFixed(2)}',
              ),

              _infoRow(
                'Status',
                service.isActive
                    ? 'Active'
                    : 'Inactive',
              ),

              const SizedBox(height: 20),

              // ====================================================
              // VENDOR
              // ====================================================

              _sectionTitle(
                context,
                'Vendor',
              ),

              _infoRow(
                'Vendor',
                service.vendorName ??
                    'Unknown vendor',
              ),

              _infoRow(
                'Vendor Email',
                service.vendorEmail ??
                    'Not available',
              ),

              _infoRow(
                'Vendor ID',
                service.vendorId,
              ),

              const SizedBox(height: 20),

              // ====================================================
              // CATEGORY
              // ====================================================

              _sectionTitle(
                context,
                'Category',
              ),

              _infoRow(
                'Category',
                service.categoryName ??
                    'Unknown category',
              ),

              _infoRow(
                'Category ID',
                service.categoryNodeId,
              ),

              const SizedBox(height: 20),

              // ====================================================
              // EVENT TYPE
              // ====================================================

              _sectionTitle(
                context,
                'Event Type',
              ),

              _infoRow(
                'Event Type',
                service.eventTypeName ??
                    'Not assigned',
              ),

              _infoRow(
                'Event Type ID',
                service.eventTypeId ??
                    'Not assigned',
              ),

              const SizedBox(height: 20),

              // ====================================================
              // DESCRIPTION
              // ====================================================

              _sectionTitle(
                context,
                'Description',
              ),

              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      Colors.grey.shade100,
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Text(
                  service.description?.isNotEmpty ==
                          true
                      ? service.description!
                      : 'No description',
                  style: const TextStyle(
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ====================================================
              // DATES
              // ====================================================

              _sectionTitle(
                context,
                'Dates',
              ),

              _infoRow(
                'Created',
                _formatDate(
                  service.createdAt,
                ),
              ),

              _infoRow(
                'Updated',
                _formatDate(
                  service.updatedAt,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(
    BuildContext context,
    String title,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _infoRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Not available';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}