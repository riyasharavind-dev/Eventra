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
        ? Colors.green.shade700
        : Colors.grey.shade700;

    final Color backgroundColor = isActive
        ? Colors.green.withValues(alpha: 0.12)
        : Colors.grey.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        ),
      ),
    );
  }
}