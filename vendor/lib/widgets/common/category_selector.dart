import 'package:eventor_vendor/services/app_settings_controller.dart';
import 'package:eventor_vendor/core/theme/app_icon_colors.dart';

import 'app_shimmer.dart';

import 'package:flutter/material.dart';

import 'category_explorer.dart';

class CategorySelector extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final Map<String, dynamic>? selectedCategory;
  final ValueChanged<Map<String, dynamic>> onCategorySelected;
  final bool enabled;
  final bool isLoading;

  const CategorySelector({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    this.enabled = true,
    this.isLoading = false,
  });

  Future<void> _openCategoryExplorer(BuildContext context) async {
    if (!enabled || isLoading) {
      return;
    }

    if (categories.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              AppSettingsScope.translate(
                context,
                "vendor.no_categories_available_please_ask_the_admin_.340de63a",
              ),
            ),
          ),
        );

      return;
    }

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return CategoryExplorer(
          categories: categories,
          selectedCategory: selectedCategory,
        );
      },
    );

    if (selected == null) {
      return;
    }

    onCategorySelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return InputDecorator(
        decoration: InputDecoration(
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.category_outlined),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: AppShimmerIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              AppSettingsScope.translate(
                context,
                "vendor.loading_categories.d3cf16ec",
              ),
            ),
          ],
        ),
      );
    }

    if (categories.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          AppSettingsScope.translate(
            context,
            "vendor.no_categories_available_please_ask_the_admin_.340de63a",
          ),
          style: TextStyle(color: Colors.red.shade700),
        ),
      );
    }

    final selected = selectedCategory;

    return InkWell(
      onTap: enabled ? () => _openCategoryExplorer(context) : null,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE8E5E8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE8E5E8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF80152C), width: 1.5),
          ),
          prefixIcon: const Icon(
            Icons.category_outlined,
            color: AppIconColors.standard,
          ),
          suffixIcon: Icon(
            Icons.chevron_right,
            color: enabled ? const Color(0xFF73737D) : Colors.grey.shade400,
          ),
        ),
        child: selected == null
            ? Text(
                AppSettingsScope.translate(
                  context,
                  "vendor.browse_categories.9ced903f",
                ),
                style: TextStyle(color: Color(0xFF73737D)),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected['name']?.toString() ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF17171B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _buildCategoryPath(selected['id'].toString()),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF73737D),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ============================================================
  // CATEGORY PATH
  // ============================================================

  String _buildCategoryPath(String categoryId) {
    final Map<String, Map<String, dynamic>> lookup = {
      for (final category in categories) category['id'].toString(): category,
    };

    final List<String> path = [];

    String? currentId = categoryId;

    final Set<String> visited = {};

    while (currentId != null && !visited.contains(currentId)) {
      visited.add(currentId);

      final category = lookup[currentId];

      if (category == null) {
        break;
      }

      path.insert(0, category['name']?.toString() ?? '');

      currentId = category['parent_id']?.toString();
    }

    return path.join(' › ');
  }
}
