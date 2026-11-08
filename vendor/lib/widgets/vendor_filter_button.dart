import 'package:eventor_vendor/core/theme/app_icon_colors.dart';
import 'package:flutter/material.dart';

class VendorFilterButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String tooltip;
  final bool active;
  const VendorFilterButton({
    super.key,
    required this.onPressed,
    required this.tooltip,
    this.active = false,
  });
  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: active,
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        foregroundColor: AppIconColors.standard,
        side: BorderSide.none,
        padding: const EdgeInsets.all(13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      icon: const Icon(Icons.filter_alt_outlined),
    ),
  );
}
