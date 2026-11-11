import 'package:eventor_customer/services/app_settings_controller.dart';

import '../explore/explore_categories.dart';

import 'package:flutter/material.dart';

import '../../models/category_node_model.dart';

/// Compact parent-category shortcuts ordered by the shared search ranking.
class HomeTrendingCategories extends StatelessWidget {
  const HomeTrendingCategories({
    super.key,
    required this.categories,
    required this.scores,
    required this.onTap,
    required this.onSeeAll,
  });

  final List<CategoryNodeModel> categories;
  final Map<String, double> scores;
  final ValueChanged<CategoryNodeModel> onTap;

  static const _wine = Color(0xFF80152C);
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final ranked = [...categories]
      ..sort((a, b) {
        final byScore = (scores[b.id] ?? 0).compareTo(scores[a.id] ?? 0);
        if (byScore != 0) return byScore;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    final visible = ranked.take(15).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 90,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: visible.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == visible.length) {
                  return SizedBox(
                    width: 76,
                    child: InkWell(
                      onTap: onSeeAll,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_forward_rounded, color: _wine),
                          SizedBox(height: 8),
                          Text(
                            AppSettingsScope.translate(
                              context,
                              "customer.see_all.d7a8c446",
                            ),
                            style: TextStyle(color: _wine),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final category = visible[index];
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    key: ValueKey('home-category-${category.id}'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onTap(category),
                    child: Container(
                      alignment: Alignment.center,
                      width: 80,
                      height: 80,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF0EDF0)),
                        boxShadow: [
                          BoxShadow(
                            color: _wine.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 34,
                            height: 34,
                            child: category.iconUrl?.isNotEmpty == true
                                ? Image.network(
                                    category.iconUrl!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => Icon(
                                      exploreCategoryIcon(category.name),
                                      color: _wine,
                                      size: 28,
                                    ),
                                  )
                                : Icon(
                                    exploreCategoryIcon(category.name),
                                    color: _wine,
                                    size: 28,
                                  ),
                          ),
                          const SizedBox(height: 5),
                          Flexible(
                            child: Text(
                              category.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _wine,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
