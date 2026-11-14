import 'package:flutter/material.dart';

class AdminAddButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String tooltip;

  const AdminAddButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Add',
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: tooltip,
      backgroundColor: const Color(0xFF80152C),
      foregroundColor: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Icon(Icons.add_rounded),
    );
  }
}
