import 'package:flutter/material.dart';

const supportWine = Color(0xFF80152C);
const supportBackground = Color(0xFFF8F8FA);

String supportDate(DateTime value) {
  final date = value.toLocal();
  return '${date.day}/${date.month}/${date.year}';
}

void showSupportError(BuildContext context, Object error) {
  debugPrint('Support error: $error');
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'Something went wrong. Check your connection and try again.',
      ),
    ),
  );
}

Widget supportPanel(Widget child) => Material(
  color: Colors.white,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: const BorderSide(color: Color(0xFFECECEF)),
  ),
  clipBehavior: Clip.antiAlias,
  child: child,
);
