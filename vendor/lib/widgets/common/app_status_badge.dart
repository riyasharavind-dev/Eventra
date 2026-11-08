import 'package:flutter/material.dart';

class AppStatusBadge extends StatelessWidget {
  final String text;
  final bool isActive;

  const AppStatusBadge({
    super.key,
    required this.text,
    required this.isActive,
  });

  const AppStatusBadge.active({
    super.key,
    this.text = 'Active',
  }) : isActive = true;

  const AppStatusBadge.inactive({
    super.key,
    this.text = 'Inactive',
  }) : isActive = false;

  @override
  Widget build(BuildContext context) {
    final Color foregroundColor = isActive
        ? const Color(0xFF2E7D32)
        : const Color(0xFF73737D);

    final Color backgroundColor = isActive
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFF4F2F4);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        ),
      ),
    );
  }
}