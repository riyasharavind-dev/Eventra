import 'package:flutter/material.dart';

import '../../models/service_model.dart';
import '../../widgets/listing_details/listing_gallery.dart';
import '../../widgets/listing_details/listing_info_section.dart';
import '../../widgets/listing_details/listing_description_section.dart';
import '../../widgets/listing_details/listing_detail_row.dart';

class ListingDetailScreen extends StatelessWidget {
  final ServiceModel service;

  /// Optional edit callback.
  final VoidCallback? onEdit;

  /// Optional activate/deactivate callback.
  final VoidCallback? onToggleStatus;

  /// Optional delete callback.
  final VoidCallback? onDelete;

  const ListingDetailScreen({
    super.key,
    required this.service,
    this.onEdit,
    this.onToggleStatus,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),

      // ==========================================================
      // APP BAR
      // ==========================================================

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,

        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: const Text(
          'Listing Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),

        actions: [
          if (onEdit != null)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(
                Icons.edit_outlined,
              ),
              onPressed: onEdit,
            ),
        ],
      ),

      // ==========================================================
      // BOTTOM ACTION BAR
      // ==========================================================

      bottomNavigationBar: _buildBottomBar(context),

      // ==========================================================
      // BODY
      // ==========================================================

      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ----------------------------------------------------
            // GALLERY
            // ----------------------------------------------------

            SliverToBoxAdapter(
              child: ListingGallery(
                gallery: service.gallery,
              ),
            ),

            // ----------------------------------------------------
            // BASIC INFORMATION
            // ----------------------------------------------------

            SliverToBoxAdapter(
              child: ListingInfoSection(
                service: service,
              ),
            ),

            // ----------------------------------------------------
            // DESCRIPTION
            // ----------------------------------------------------

            SliverToBoxAdapter(
              child: ListingDescriptionSection(
                description: service.description,
              ),
            ),

            // ----------------------------------------------------
            // LISTING INFORMATION
            // ----------------------------------------------------

            SliverToBoxAdapter(
              child: _buildDetailsSection(),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LISTING INFORMATION
  // ============================================================

  Widget _buildDetailsSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        0,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Listing Information',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 18),

          // ------------------------------------------------------
          // CATEGORY
          // ------------------------------------------------------

          ListingDetailRow(
            icon: Icons.category_outlined,
            title: 'Category',
            value: service.categoryName ??
                'Not available',
          ),

          // ------------------------------------------------------
          // PRICE
          // ------------------------------------------------------

          ListingDetailRow(
            icon: Icons.sell_outlined,
            title: 'Price',
            value:
                '₹${service.price.toStringAsFixed(2)}',
          ),

          // ------------------------------------------------------
          // STATUS
          // ------------------------------------------------------

          ListingDetailRow(
            icon: service.isActive
                ? Icons.check_circle_outline
                : Icons.pause_circle_outline,
            title: 'Status',
            value: service.isActive
                ? 'Active'
                : 'Inactive',
            valueColor: service.isActive
                ? Colors.green
                : Colors.orange,
          ),

          // ------------------------------------------------------
          // SERVICE ID
          // ------------------------------------------------------

          ListingDetailRow(
            icon: Icons.tag_outlined,
            title: 'Service ID',
            value: service.id,
          ),

          // ------------------------------------------------------
          // VENDOR ID
          // ------------------------------------------------------

          ListingDetailRow(
            icon: Icons.person_outline,
            title: 'Vendor ID',
            value: service.vendorId,
          ),

          // ------------------------------------------------------
          // SLUG
          // ------------------------------------------------------

          if (service.slug.trim().isNotEmpty)
            ListingDetailRow(
              icon: Icons.link_outlined,
              title: 'Slug',
              value: service.slug,
            ),

          // ------------------------------------------------------
          // CREATED
          // ------------------------------------------------------

          if (service.createdAt != null)
            ListingDetailRow(
              icon: Icons.calendar_today_outlined,
              title: 'Created',
              value:
                  _formatDate(service.createdAt!),
            ),

          // ------------------------------------------------------
          // UPDATED
          // ------------------------------------------------------

          if (service.updatedAt != null)
            ListingDetailRow(
              icon: Icons.update_outlined,
              title: 'Last Updated',
              value:
                  _formatDate(service.updatedAt!),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM BAR
  // ============================================================

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.06,
            ),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // ----------------------------------------------------
            // STATUS BUTTON
            // ----------------------------------------------------

            Expanded(
              child: OutlinedButton.icon(
                onPressed: onToggleStatus,
                icon: Icon(
                  service.isActive
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                ),
                label: Text(
                  service.isActive
                      ? 'Deactivate'
                      : 'Activate',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize:
                      const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            // ----------------------------------------------------
            // EDIT BUTTON
            // ----------------------------------------------------

            Expanded(
              child: ElevatedButton.icon(
                onPressed: onEdit,
                icon: const Icon(
                  Icons.edit_outlined,
                ),
                label: const Text(
                  'Edit',
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize:
                      const Size.fromHeight(50),
                  backgroundColor:
                      Theme.of(context)
                          .colorScheme
                          .primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDate(DateTime date) {
    final day =
        date.day.toString().padLeft(2, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    final year =
        date.year.toString();

    final hour = date.hour > 12
        ? date.hour - 12
        : date.hour == 0
            ? 12
            : date.hour;

    final minute =
        date.minute.toString().padLeft(2, '0');

    final period =
        date.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/$year • '
        '$hour:$minute $period';
  }
}