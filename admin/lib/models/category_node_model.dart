class CategoryNodeModel {
  final String id;
  final String name;
  final String slug;
  final String? parentId;
  final DateTime? createdAt;

  const CategoryNodeModel({
    required this.id,
    required this.name,
    required this.slug,
    this.parentId,
    this.createdAt,
  });

  factory CategoryNodeModel.fromMap(Map<String, dynamic> map) {
    return CategoryNodeModel(
      id: map['id'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
      parentId: map['parent_id'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'parent_id': parentId,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}