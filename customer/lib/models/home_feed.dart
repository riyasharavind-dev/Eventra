class HomeFeedItem {
  final Map<String, dynamic> data;
  const HomeFeedItem(this.data);
  String get id => data['id'].toString();
  bool get isVendor => data['type'] == 'vendors';
  String get name => data['name']?.toString() ?? '';
  String get description => data['description']?.toString() ?? '';
  String? get image => data['image_url'] as String?;
  num? get rating => data['rating'] as num?;
  num get price => data['price'] as num? ?? 0;
}

class HomeFeedSection {
  final String id, title, layout;
  final List<HomeFeedItem> items;
  final bool hasMore;
  HomeFeedSection(Map<String, dynamic> data)
    : id = data['id'].toString(),
      title = data['title'].toString(),
      layout = data['layout']?.toString() ?? 'horizontal',
      hasMore = data['has_more'] == true,
      items = (data['items'] as List? ?? [])
          .map((e) => HomeFeedItem(Map<String, dynamic>.from(e as Map)))
          .toList();
}
