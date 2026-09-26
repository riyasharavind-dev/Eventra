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
      child: const Icon(Icons.add),
    );
  }
}