import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/explore_data.dart';
import 'category_repository.dart';

class ExploreRepository {
  ExploreRepository({CategoryRepository? categories, SupabaseClient? client})
    : _categories = categories ?? CategoryRepository(client: client),
      _client = client;
  final CategoryRepository _categories;
  final SupabaseClient? _client;
  SupabaseClient get db => _client ?? Supabase.instance.client;
  Map<String, double> _lastRankings = {};
  Future<Map<String, double>> rankings() async {
    try {
      _lastRankings = {
        for (final row in (await db.rpc('customer_category_rankings') as List))
          row['category_id'] as String: (row['score'] as num).toDouble(),
      };
      return _lastRankings;
    } catch (_) {
      return _lastRankings;
    }
  }

  Future<ExploreData> load() async {
    final ranks = rankings();
    final categories = await _categories.getCategories();
    return ExploreData(
      categories: categories,
      services: const [],
      categoryScores: await ranks,
    );
  }
}
