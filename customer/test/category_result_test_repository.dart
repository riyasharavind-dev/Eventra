import 'package:eventor_customer/models/explore_data.dart';
import 'package:eventor_customer/models/customer_search_model.dart';
import 'package:eventor_customer/repositories/customer_search_repository.dart';

class CategoryResultTestRepository implements CustomerSearchRepository {
  CategoryResultTestRepository(this.data);
  final ExploreData data;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<CustomerSearchPage> categoryResults(
    String categoryId, {
    String kind = 'all',
    String sort = 'relevance',
    int offset = 0,
  }) async => CustomerSearchPage(
    items: [
      for (final service in data.servicesFor(categoryId))
        CustomerSearchResult({
          'id': service.id,
          'type': 'services',
          'name': service.name,
          'price': service.price,
          'image_url': service.gallery.firstOrNull,
          'pricing_type': service.pricing.toMap()['pricing_type'],
          'pricing_unit': service.pricing.toMap()['pricing_unit'],
          'service': service.toMap(),
        }),
    ],
    hasMore: false,
  );
}
