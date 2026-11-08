import 'home_feed.dart';

class RecommendationPage {
  final List<HomeFeedItem> items;
  final bool hasMore, personalized;
  final int nextOffset;
  RecommendationPage(Map<String, dynamic> data)
    : items = (data['items'] as List? ?? [])
          .map((e) => HomeFeedItem(Map<String, dynamic>.from(e as Map)))
          .toList(),
      hasMore = data['has_more'] == true,
      personalized = data['personalized'] == true,
      nextOffset = (data['next_offset'] as num? ?? 0).toInt();
}
