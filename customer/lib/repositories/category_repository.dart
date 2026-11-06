import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category_node_model.dart';

class CategoryRepository {
  CategoryRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;
  Future<List<CategoryNodeModel>> getCategories() async {
    final result = <CategoryNodeModel>[];
    for (var offset = 0; ; offset += 200) {
      final rows = await _client
          .from('category_nodes')
          .select('id,name,slug,parent_id,created_at')
          .order('name')
          .order('id')
          .range(offset, offset + 199);
      result.addAll(rows.map(CategoryNodeModel.fromMap));
      if (rows.length < 200) break;
    }
    return result;
  }

  Future<List<CategoryNodeModel>> getParentCategories() async =>
      (await getCategories())
          .where((category) => category.parentId == null)
          .toList();
}
