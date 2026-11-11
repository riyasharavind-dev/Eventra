import 'package:eventor_vendor/services/app_settings_controller.dart';
import 'package:eventor_vendor/core/theme/app_icon_colors.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ServiceGalleryPicker extends StatelessWidget {
  final List<XFile> images;
  final VoidCallback onAddImages;
  final ValueChanged<int> onRemoveImage;
  final bool enabled;

  const ServiceGalleryPicker({
    super.key,
    required this.images,
    required this.onAddImages,
    required this.onRemoveImage,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return _buildEmptyPicker(context);
    }

    return _buildImageGrid();
  }

  // ============================================================
  // EMPTY PICKER
  // ============================================================

  Widget _buildEmptyPicker(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onAddImages : null,
      child: Container(
        width: double.infinity,
        height: 130,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 42,
              color: AppIconColors.standard,
            ),
            SizedBox(height: 8),
            Text(
              AppSettingsScope.translate(
                context,
                "vendor.add_service_images.8c3e5df3",
              ),
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // IMAGE GRID
  // ============================================================

  Widget _buildImageGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: images.length + 1,
      itemBuilder: (context, index) {
        // Last item = Add more button
        if (index == images.length) {
          return _buildAddMoreButton();
        }

        return _buildImageItem(image: images[index], index: index);
      },
    );
  }

  // ============================================================
  // IMAGE ITEM
  // ============================================================

  Widget _buildImageItem({required XFile image, required int index}) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(File(image.path), fit: BoxFit.cover),
          ),
        ),

        // Remove button
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: enabled ? () => onRemoveImage(index) : null,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ADD MORE BUTTON
  // ============================================================

  Widget _buildAddMoreButton() {
    return GestureDetector(
      onTap: enabled ? onAddImages : null,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.add, size: 30, color: AppIconColors.standard),
      ),
    );
  }
}
