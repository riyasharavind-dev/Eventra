import '../models/category_node_model.dart';
import '../models/explore_data.dart';
import '../models/service_model.dart';
import 'category_repository.dart';
import 'service_repository.dart';

class ExploreRepository {
  ExploreRepository({
    CategoryRepository? categories,
    ServiceRepository? services,
  }) : _categories = categories ?? CategoryRepository(),
       _services = services ?? ServiceRepository();
  final CategoryRepository _categories;
  final ServiceRepository _services;
  Future<ExploreData> load() async {
    final values = await Future.wait<Object>([
      _categories.getCategories(),
      _services.getActiveServices(),
    ]);
    return ExploreData(
      categories: values[0] as List<CategoryNodeModel>,
      services: values[1] as List<ServiceModel>,
    );
  }
}
