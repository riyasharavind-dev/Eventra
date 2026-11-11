import 'package:eventor_customer/services/app_settings_controller.dart';
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
    SnackBar(
      content: Text(
        AppSettingsScope.translate(
          context,
          "customer.something_went_wrong_check_your_connection_an.067b61d2",
        ),
      ),
    ),
  );
}

Widget supportPanel(Widget child) => Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFFF0EDF0)),
    boxShadow: [
      BoxShadow(
        color: supportWine.withValues(alpha: 0.04),
        blurRadius: 14,
        offset: const Offset(0, 4),
      ),
    ],
  ),
  clipBehavior: Clip.antiAlias,
  child: Material(
    color: Colors.transparent,
    child: child,
  ),
);
