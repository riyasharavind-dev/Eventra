import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category_node_model.dart';

class CategoryRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // GET PARENT CATEGORIES
  // ============================================================

  Future<List<CategoryNodeModel>> getParentCategories() async {
    final data = await _supabase
        .from('category_nodes')
        .select()
        .isFilter('parent_id', null)
        .order('name');

    return (data as List)
        .map(
          (item) => CategoryNodeModel.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  // ============================================================
  // GET CHILDREN OF A CATEGORY
  // ============================================================

  Future<List<CategoryNodeModel>> getChildren(
    String parentId,
  ) async {
    final data = await _supabase
        .from('category_nodes')
        .select()
        .eq('parent_id', parentId)
        .order('name');

    return (data as List)
        .map(
          (item) => CategoryNodeModel.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  // ============================================================
  // GET CATEGORY BY ID
  // ============================================================

  Future<CategoryNodeModel?> getCategoryById(
    String categoryId,
  ) async {
    final data = await _supabase
        .from('category_nodes')
        .select()
        .eq('id', categoryId)
        .maybeSingle();

    if (data == null) {
      return null;
    }

    return CategoryNodeModel.fromMap(data);
  }
}