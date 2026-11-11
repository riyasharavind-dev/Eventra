import 'package:flutter/material.dart';

class ServiceDetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const ServiceDetailRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ====================================================
        // ICON
        // ====================================================

        Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFF5E8EC),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF80152C)),
        ),

        const SizedBox(width: 12),

        // ====================================================
        // TEXT
        // ====================================================
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Color(0xFF73737D)),
              ),

              const SizedBox(height: 3),

              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF17171B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
