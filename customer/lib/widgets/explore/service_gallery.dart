import 'package:flutter/material.dart';

class ServiceGallery extends StatelessWidget {
  final List<String> gallery;
  final double height;
  final BorderRadius borderRadius;

  const ServiceGallery({
    super.key,
    required this.gallery,
    this.height = 150,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  @override
  Widget build(BuildContext context) {
    if (gallery.isEmpty) {
      return Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: borderRadius,
        ),
        child: const Center(
          child: Icon(Icons.image_outlined, size: 42, color: Colors.grey),
        ),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Image.network(
          gallery.first,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }

            return Container(
              color: Colors.grey.shade300,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey.shade300,
              child: const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 42,
                  color: Colors.grey,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
