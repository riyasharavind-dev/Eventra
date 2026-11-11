import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:flutter/material.dart';

class ServiceActionBar extends StatelessWidget {
  const ServiceActionBar({
    super.key,
    required this.onAddService,
    required this.onBookService,
    this.adding = false,
  });
  final VoidCallback onAddService, onBookService;
  final bool adding;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0EDF0))),
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: adding ? null : onAddService,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFCB48),
                  foregroundColor: const Color(0xFF17171B),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                child: Text(
                  adding ? 'Adding…' : 'Add Service',
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: onBookService,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF80152C),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                child: Text(
                  AppSettingsScope.translate(
                    context,
                    "customer.book_now.67be7935",
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
