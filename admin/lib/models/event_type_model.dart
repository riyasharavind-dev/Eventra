class EventTypeModel {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? icon;
  final String? imageUrl;
  final bool isActive;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const EventTypeModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.icon,
    this.imageUrl,
    required this.isActive,
    required this.sortOrder,
    this.createdAt,
    this.updatedAt,
  });

  factory EventTypeModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return EventTypeModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      slug: map['slug']?.toString() ?? '',
      description: map['description']?.toString(),
      icon: map['icon']?.toString(),
      imageUrl: map['image_url']?.toString(),
      isActive: map['is_active'] == true,
      sortOrder: map['sort_order'] is int
          ? map['sort_order'] as int
          : int.tryParse(
                map['sort_order']?.toString() ?? '',
              ) ??
              0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(
              map['created_at'].toString(),
            )
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(
              map['updated_at'].toString(),
            )
          : null,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'name': name,
      'slug': slug,
      'description': description,
      'icon': icon,
      'image_url': imageUrl,
      'is_active': isActive,
      'sort_order': sortOrder,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'name': name,
      'slug': slug,
      'description': description,
      'icon': icon,
      'image_url': imageUrl,
      'is_active': isActive,
      'sort_order': sortOrder,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}