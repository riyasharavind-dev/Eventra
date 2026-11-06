import 'package:flutter/material.dart';

import '../../models/category_node_model.dart';

const exploreWine = Color(0xFF80152C);

IconData exploreCategoryIcon(String name) {
  final text = name.toLowerCase();
  if (text.contains('flower') || text.contains('floral')) {
    return Icons.local_florist_outlined;
  }
  if (text.contains('decor') || text.contains('stage')) {
    return Icons.celebration_outlined;
  }
  if (text.contains('cater') ||
      text.contains('food') ||
      text.contains('buff')) {
    return Icons.restaurant_outlined;
  }
  if (text.contains('photo') || text.contains('video')) {
    return Icons.photo_camera_outlined;
  }
  if (text.contains('music') || text.contains('dj') || text.contains('audio')) {
    return Icons.music_note_outlined;
  }
  if (text.contains('beauty') || text.contains('makeup')) {
    return Icons.face_retouching_natural;
  }
  if (text.contains('venue') || text.contains('hall')) {
    return Icons.location_city_outlined;
  }
  if (text.contains('car') || text.contains('transport')) {
    return Icons.directions_car_outlined;
  }
  if (text.contains('cake')) return Icons.cake_outlined;
  return Icons.category_outlined;
}

class ExploreCategoryRail extends StatelessWidget {
  const ExploreCategoryRail({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelect,
  });
  final List<CategoryNodeModel> categories;
  final String? selected;
  final ValueChanged<String?> onSelect;
  @override
  Widget build(BuildContext context) => Container(
    width: MediaQuery.sizeOf(context).width < 360 ? 82 : 96,
    decoration: const BoxDecoration(
      color: Color(0xFFF4F4F7),
      border: Border(right: BorderSide(color: Color(0xFFECECF1))),
    ),
    child: ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 128),
      itemCount: categories.length + 1,
      itemBuilder: (context, index) {
        final category = index == 0 ? null : categories[index - 1];
        final active = selected == category?.id;
        final name = category?.name ?? 'All';
        return Semantics(
          selected: active,
          button: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey('parent-${category?.id ?? 'all'}'),
              onTap: () => onSelect(category?.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.transparent,
                  border: Border(
                    left: BorderSide(
                      color: active ? exploreWine : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      category == null
                          ? Icons.apps_rounded
                          : exploreCategoryIcon(name),
                      size: 30,
                      color: active ? exploreWine : const Color(0xFF73737D),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? exploreWine : const Color(0xFF555561),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class ExploreChildCategories extends StatelessWidget {
  const ExploreChildCategories({
    super.key,
    required this.categories,
    required this.onSelect,
  });
  final List<CategoryNodeModel> categories;
  final ValueChanged<CategoryNodeModel> onSelect;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 440 ? 3 : 2;
      final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 14,
        children: categories
            .map(
              (category) => SizedBox(
                width: width,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: ValueKey('child-${category.id}'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onSelect(category),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            height: 78,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F0F3),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              exploreCategoryIcon(category.name),
                              size: 36,
                              color: exploreWine,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            category.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF282837),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

class ExploreCategoryTrail extends StatelessWidget {
  const ExploreCategoryTrail({
    super.key,
    required this.path,
    required this.onSelect,
  });
  final List<CategoryNodeModel> path;
  final ValueChanged<String?> onSelect;
  @override
  Widget build(BuildContext context) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      TextButton(onPressed: () => onSelect(null), child: const Text('All')),
      for (final category in path) ...[
        const Icon(
          Icons.chevron_right_rounded,
          size: 16,
          color: Color(0xFF73737D),
        ),
        TextButton(
          onPressed: () => onSelect(category.id),
          child: Text(category.name),
        ),
      ],
    ],
  );
}
