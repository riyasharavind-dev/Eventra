import 'package:eventor_customer/services/app_settings_controller.dart';
import '../../core/theme/app_icon_colors.dart';
import 'package:flutter/material.dart';

class AppSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const AppSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Search',
    this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ========================================================
        // SEARCH FIELD
        // ========================================================
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF0EDF0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                  color: Color(0xFF73737D),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 22,
                  color: AppIconColors.standard,
                ),
                suffixIcon: IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.mic_none_outlined,
                    size: 21,
                    color: AppIconColors.standard,
                  ),
                  tooltip: AppSettingsScope.translate(
                    context,
                    "customer.voice_search.f4f997cf",
                  ),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        // ========================================================
        // CLOSE BUTTON
        // ========================================================
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            border: Border.all(color: const Color(0xFFF0EDF0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                controller.clear();
                onClear?.call();
              } else {
                FocusScope.of(context).unfocus();
              }
            },
            icon: const Icon(
              Icons.close,
              size: 22,
              color: AppIconColors.standard,
            ),
            tooltip: AppSettingsScope.translate(
              context,
              "customer.clear.83b12c22",
            ),
          ),
        ),
      ],
    );
  }
}
