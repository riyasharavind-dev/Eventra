import 'category_node_model.dart';
import 'service_model.dart';

class ExploreData {
  const ExploreData({required this.categories, required this.services});
  final List<CategoryNodeModel> categories;
  final List<ServiceModel> services;
  List<CategoryNodeModel> get parents =>
      categories.where((category) => category.parentId == null).toList();
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
