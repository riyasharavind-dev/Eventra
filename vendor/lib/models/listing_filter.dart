import 'service_model.dart';

List<ServiceModel> filterListings(
  List<ServiceModel> services, {
  String query = '',
  String status = 'all',
  String business = 'all',
  String category = 'all',
  String sort = 'newest',
}) {
  final search = query.trim().toLowerCase();
  final rows = services.where((s) {
    if (status == 'active' && !s.isActive ||
        status == 'inactive' && s.isActive) {
      return false;
    }
    if (business != 'all' &&
        (business == 'unassigned'
            ? s.businessId != null
            : s.businessId != business)) {
      return false;
    }
    if (category != 'all' && s.categoryNodeId != category) {
      return false;
    }
    return search.isEmpty ||
        [
          s.name,
          s.description ?? '',
          s.slug,
          s.categoryName ?? '',
        ].any((v) => v.toLowerCase().contains(search));
  }).toList();
  rows.sort((a, b) {
    final result = switch (sort) {
      'price_low' => a.price.compareTo(b.price),
      'price_high' => b.price.compareTo(a.price),
      'name' => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      _ => b.createdAt.compareTo(a.createdAt),
    };
    return result == 0 ? a.id.compareTo(b.id) : result;
  });
  return rows;
}
