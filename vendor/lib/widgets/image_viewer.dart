import 'package:eventor_vendor/core/theme/app_icon_colors.dart';

import 'common/app_shimmer.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Circular photo popup that leaves the current screen visible underneath.
class ImageViewer extends StatelessWidget {
  const ImageViewer({super.key, this.imageUrl, this.title = 'Profile photo'});
  final String? imageUrl;
  final String title;

  static Future<void> show(
    BuildContext context, {
    String? imageUrl,
    String title = 'Profile photo',
  }) => showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (_) => ImageViewer(imageUrl: imageUrl, title: title),
  );

  Widget _placeholder(String message) => ColoredBox(
    color: const Color(0xFFF4E6EB),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_outline,
              color: AppIconColors.standard,
              size: 72,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF80152C), fontSize: 14),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim() ?? '';
    final size = MediaQuery.sizeOf(context);
    final diameter = math.min(
      300.0,
      math.min(size.width - 48, size.height - 96),
    );
    return Dialog(
      constraints: BoxConstraints.tightFor(width: diameter, height: diameter),
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: Semantics(
        label: title,
        image: true,
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(4),
          child: ClipOval(
            child: url.isEmpty
                ? _placeholder('No profile photo yet')
                : Image.network(
                    url,
                    width: diameter,
                    height: diameter,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                        ? child
                        : ColoredBox(
                            color: Color(0xFFF4E6EB),
                            child: AppShimmer(
                              child: SkeletonBox(
                                width: diameter,
                                height: diameter,
                                radius: 0,
                              ),
                            ),
                          ),
                    errorBuilder: (_, error, stack) =>
                        _placeholder('Unable to load photo'),
                  ),
          ),
        ),
      ),
    );
  }
}
