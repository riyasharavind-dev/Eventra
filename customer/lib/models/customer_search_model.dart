import 'home_feed.dart';
import 'service_pricing.dart';

String normalizeSearch(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

class RecentCustomerSearch {
  const RecentCustomerSearch({required this.query, required this.searchedAt});
  final String query;
  final DateTime searchedAt;
  factory RecentCustomerSearch.fromMap(Map<String, dynamic> map) =>
      RecentCustomerSearch(
        query: normalizeSearch(map['query']?.toString() ?? ''),
        searchedAt:
            DateTime.tryParse(map['searched_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
  Map<String, dynamic> toMap() => {
    'query': query,
    'searched_at': searchedAt.toUtc().toIso8601String(),
  };
}

class CustomerSearchResult {
  const CustomerSearchResult(this.data);
  final Map<String, dynamic> data;
  HomeFeedItem get feedItem => HomeFeedItem(data);
  String get id => '${data['type']}:${data['id']}';
  String get name => feedItem.name;
  bool get isVendor => feedItem.isVendor;
  String get subtitle => isVendor
      ? 'Vendor'
      : [
          data['category_name'],
          data['vendor_name'],
        ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
  String get priceLabel =>
      ServicePricing.fromMap(data).format(feedItem.price.toDouble());
}

class CustomerSearchPage {
  const CustomerSearchPage({required this.items, required this.hasMore});
  final List<CustomerSearchResult> items;
  final bool hasMore;
  factory CustomerSearchPage.fromMap(Map<String, dynamic> map) =>
      CustomerSearchPage(
        items: (map['items'] as List? ?? [])
            .map(
              (item) =>
                  CustomerSearchResult(Map<String, dynamic>.from(item as Map)),
            )
            .toList(),
        hasMore: map['has_more'] == true,
      );
}
