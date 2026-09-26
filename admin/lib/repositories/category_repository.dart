import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category_node_model.dart';

class CategoryRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all categories
  Future<List<CategoryNodeModel>> getCategories() async {
    final response = await _supabase
        .from('category_nodes')
        .select()
        .order('name', ascending: true);

    return (response as List)
        .map(
          (item) => CategoryNodeModel.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  /// Get only root categories
  Future<List<CategoryNodeModel>> getRootCategories() async {
    final response = await _supabase
        .from('category_nodes')
        .select()
        .isFilter('parent_id', null)
        .order('name', ascending: true);

    return (response as List)
        .map(
          (item) => CategoryNodeModel.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  /// Get children of a category
  Future<List<CategoryNodeModel>> getChildren(
    String parentId,
  ) async {
    final response = await _supabase
        .from('category_nodes')
        .select()
        .eq('parent_id', parentId)
        .order('name', ascending: true);

    return (response as List)
        .map(
          (item) => CategoryNodeModel.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  /// Add a new category
  Future<CategoryNodeModel> addCategory({
    required String name,
    required String slug,
    String? parentId,
  }) async {
    final response = await _supabase
        .from('category_nodes')
        .insert({
          'name': name.trim(),
          'slug': slug.trim(),
          'parent_id': parentId,
        })
        .select()
        .single();

    return CategoryNodeModel.fromMap(
      Map<String, dynamic>.from(response),
    );
  }

  /// Update category
  Future<CategoryNodeModel> updateCategory({
    required String id,
    required String name,
    required String slug,
    String? parentId,
  }) async {
    final response = await _supabase
        .from('category_nodes')
        .update({
          'name': name.trim(),
          'slug': slug.trim(),
          'parent_id': parentId,
        })
        .eq('id', id)
        .select()
        .single();

    return CategoryNodeModel.fromMap(
      Map<String, dynamic>.from(response),
    );
  }

  /// Delete category
  Future<void> deleteCategory(String id) async {
    await _supabase
        .from('category_nodes')
        .delete()
        .eq('id', id);
  }
}