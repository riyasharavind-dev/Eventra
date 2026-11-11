import 'package:flutter/material.dart';

import '../../models/category_node_model.dart';
import 'explore_categories.dart';

/// Shared three-column category grid for both All and parent-category views.
class ExploreCards extends StatelessWidget {
  const ExploreCards({
    super.key,
    required this.categories,
    required this.onSelect,
  });
  final List<CategoryNodeModel> categories;
  final ValueChanged<CategoryNodeModel> onSelect;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = 8.0;
      final width = (constraints.maxWidth - spacing * 2) / 3;
      return Wrap(
        spacing: spacing,
        runSpacing: 14,
        children: [
          for (final category in categories)
            SizedBox(
              width: width,
              child: ExploreCategoryCard(
                category: category,
                onTap: () => onSelect(category),
              ),
            ),
        ],
      );
    },
  );
}

class ExploreCategoryCard extends StatelessWidget {
  const ExploreCategoryCard({
    super.key,
    required this.category,
    required this.onTap,
  });
  final CategoryNodeModel category;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      key: ValueKey('child-${category.id}'),
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5E8EC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF0EDF0)),
                ),
                child: Icon(
                  exploreCategoryIcon(category.name),
                  size: 28,
                  color: exploreWine,
                ),
              ),
            ),
            const SizedBox(height: 7),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                category.name.trim().split(RegExp(r'\s+')).join('\n'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF17171B),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
