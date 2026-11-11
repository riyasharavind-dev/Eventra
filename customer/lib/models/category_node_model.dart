class CategoryNodeModel {
  final String id;
  final String name;
  final String slug;
  final String? iconUrl;
  final String? parentId;
  final DateTime createdAt;

  const CategoryNodeModel({
    required this.id,
    required this.name,
    required this.slug,
    this.parentId,
    this.iconUrl,
    required this.createdAt,
  });

  factory CategoryNodeModel.fromMap(Map<String, dynamic> map) {
    return CategoryNodeModel(
      id: map['id'] as String,
      name: map['name'] as String,
      slug: map['slug'] as String,
      iconUrl: map['icon_url']?.toString(),
      parentId: map['parent_id'] as String?,
      createdAt: DateTime.parse(map['created_at'].toString()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'icon_url': iconUrl,
      'parent_id': parentId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
