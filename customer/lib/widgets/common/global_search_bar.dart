import 'package:flutter/material.dart';

/// Reusable search input with a clean, compact UI.
class GlobalSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;
  final String clearLabel;

  const GlobalSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hintText,
    this.clearLabel = 'Clear search',
  });

  static const Color _wine = Color(0xFF80152C);
  static const Color _hintColor = Color(0xFF777783);
  static const Color _borderColor = Color(0xFFE8E5EB);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        return Container(
          height: 49,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: _borderColor,
              width: 1,
            ),
          ),
          child: Center(
            child: TextField(
              key: const ValueKey('global-search-input'),
              controller: controller,
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
                suffixIcon: value.text.isEmpty
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
                  borderSide: const BorderSide(
                    color: _wine,
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}