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
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.grey.shade200,
              ),
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 15,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 22,
                ),
                suffixIcon: IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.mic_none_outlined,
                    size: 21,
                  ),
                  tooltip: 'Voice Search',
                ),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(
                  vertical: 13,
                ),
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
            shape: BoxShape.circle,
            color: Colors.grey.shade100,
            border: Border.all(
              color: Colors.grey.shade200,
            ),
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
              size: 23,
            ),
            tooltip: 'Clear',
          ),
        ),
      ],
    );
  }
}