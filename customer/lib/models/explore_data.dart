import 'category_node_model.dart';
import 'service_model.dart';

class ExploreData {
  const ExploreData({
    required this.categories,
    required this.services,
    this.categoryScores = const {},
  });
  final List<CategoryNodeModel> categories;
  final List<ServiceModel> services;
  final Map<String, double> categoryScores;
  List<CategoryNodeModel> ordered(List<CategoryNodeModel> nodes) {
    final positions = {
      for (var i = 0; i < categories.length; i++) categories[i].id: i,
    };
    return [...nodes]..sort((a, b) {
      final score = (categoryScores[b.id] ?? 0).compareTo(
        categoryScores[a.id] ?? 0,
      );
      return score != 0
          ? score
          : (positions[a.id] ?? 0).compareTo(positions[b.id] ?? 0);
    });
  }

  List<CategoryNodeModel> descendantsFor(String parentId) {
    final children = <String, List<CategoryNodeModel>>{};
    for (final node in categories) {
      if (node.parentId != null) (children[node.parentId!] ??= []).add(node);
    }
    final result = <CategoryNodeModel>[];
    final visited = {parentId};
    final pending = [parentId];
    for (var i = 0; i < pending.length; i++) {
      for (final child in children[pending[i]] ?? <CategoryNodeModel>[]) {
        if (visited.add(child.id)) {
          result.add(child);
          pending.add(child.id);
        }
      }
    }
    return ordered(result);
  }

  List<CategoryNodeModel> get parents => ordered(
    categories.where((category) => category.parentId == null).toList(),
  );
  List<CategoryNodeModel> childrenFor(String? id) =>
      categories.where((category) => category.parentId == id).toList();
  List<CategoryNodeModel> pathFor(String? id) {
    final byId = {for (final category in categories) category.id: category};
    final path = <CategoryNodeModel>[];
    final visited = <String>{};
    while (id != null && visited.add(id)) {
      final category = byId[id];
      if (category == null) break;
      path.insert(0, category);
      id = category.parentId;
    }
    return path;
  }

  List<ServiceModel> servicesFor(String? parentId) {
    if (parentId == null) return services;
    final byId = {for (final category in categories) category.id: category};
    return services.where((service) {
      String? current = service.categoryNodeId;
      final visited = <String>{};
      while (current != null && visited.add(current)) {
        if (current == parentId) return true;
        current = byId[current]?.parentId;
      }
      return false;
    }).toList();
  }
}
