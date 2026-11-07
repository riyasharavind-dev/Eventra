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
    child: IconButton.outlined(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        foregroundColor: const Color(0xFF80152C),
        side: const BorderSide(color: Color(0xFFD58C9E)),
        padding: const EdgeInsets.all(13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      icon: const Icon(Icons.filter_alt_outlined),
    ),
  );
}
