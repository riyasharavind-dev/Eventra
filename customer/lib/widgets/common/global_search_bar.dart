import 'package:flutter/material.dart';

/// Reusable search input with a clean, compact UI.
class GlobalSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;
  final String clearLabel;
  final bool readOnly;
  final VoidCallback? onTap;

  const GlobalSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hintText,
    this.clearLabel = 'Clear search',
    this.readOnly = false,
    this.onTap,
  });

  static const Color _wine = Color(0xFF80152C);
  static const Color _hintColor = Color(0xFF73737D);
  static const Color _borderColor = Color(0xFFF0EDF0);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        return Container(
          height: 49,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: TextField(
              key: const ValueKey('global-search-input'),
              controller: controller,
              readOnly: readOnly,
              showCursor: !readOnly,
              onTap: onTap,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Color(0xFF17171B),
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                  color: _hintColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _hintColor,
                  size: 23,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 45,
                  minHeight: 49,
                ),
                suffixIcon: readOnly || value.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: clearLabel,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: _hintColor,
                          size: 19,
                        ),
                        onPressed: () {
                          controller.clear();
                          onChanged('');
                        },
                      ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 38,
                  minHeight: 49,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: 0,
                ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: _wine, width: 1.2),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
