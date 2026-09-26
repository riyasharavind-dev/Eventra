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

  Future<void> _openCategoryExplorer(
    BuildContext context,
  ) async {
    if (!enabled || isLoading) {
      return;
    }

    if (categories.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'No categories available. Please ask the admin to create categories.',
            ),
          ),
        );

      return;
    }

    final selected =
        await showModalBottomSheet<Map<String, dynamic>>(
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
      return const InputDecorator(
        decoration: InputDecoration(
          border: OutlineInputBorder(),
          prefixIcon: Icon(
            Icons.category_outlined,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Loading categories...',
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
          border: Border.all(
            color: Colors.red.shade300,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'No categories available. '
          'Please ask the admin to create categories.',
          style: TextStyle(
            color: Colors.red.shade700,
          ),
        ),
      );
    }

    final selected = selectedCategory;

    return InkWell(
      onTap: enabled
          ? () => _openCategoryExplorer(context)
          : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(
            Icons.category_outlined,
          ),
          suffixIcon: Icon(
            Icons.chevron_right,
            color: enabled
                ? null
                : Colors.grey.shade400,
          ),
        ),
        child: selected == null
            ? const Text(
                'Browse categories',
                style: TextStyle(
                  color: Colors.grey,
                ),
              )
            : Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    selected['name']
                            ?.toString() ??
                        '',
                    style: const TextStyle(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _buildCategoryPath(
                      selected['id'].toString(),
                    ),
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
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

  String _buildCategoryPath(
    String categoryId,
  ) {
    final Map<String, Map<String, dynamic>>
        lookup = {
      for (final category in categories)
        category['id'].toString(): category,
    };

    final List<String> path = [];

    String? currentId = categoryId;

    final Set<String> visited = {};

    while (
        currentId != null &&
        !visited.contains(currentId)) {
      visited.add(currentId);

      final category = lookup[currentId];

      if (category == null) {
        break;
      }

      path.insert(
        0,
        category['name']?.toString() ?? '',
      );

      currentId =
          category['parent_id']?.toString();
    }

    return path.join(' › ');
  }
}