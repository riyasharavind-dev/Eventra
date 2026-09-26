class ServiceModel {
  final String id;
  final String vendorId;
  final String categoryNodeId;

  final String name;
  final String slug;
  final String? description;

  final double price;

  final List<String> gallery;

  final bool isActive;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Category information
  final String? categoryId;
  final String? categoryName;
  final String? categorySlug;
  final String? categoryParentId;

  const ServiceModel({
    required this.id,
    required this.vendorId,
    required this.categoryNodeId,
    required this.name,
    required this.slug,
    this.description,
    required this.price,
    required this.gallery,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.categoryId,
    this.categoryName,
    this.categorySlug,
    this.categoryParentId,
  });

  // ============================================================
  // FROM SUPABASE
  // ============================================================

  factory ServiceModel.fromMap(
    Map<String, dynamic> map,
  ) {
    final dynamic category =
        map['category_nodes'];

    Map<String, dynamic>? categoryMap;

    if (category is Map) {
      categoryMap =
          Map<String, dynamic>.from(category);
    }

    return ServiceModel(
      id: map['id']?.toString() ?? '',
      vendorId:
          map['vendor_id']?.toString() ?? '',
      categoryNodeId:
          map['category_node_id']?.toString() ?? '',

      name:
          map['name']?.toString() ??
              'Unnamed Service',

      slug:
          map['slug']?.toString() ?? '',

      description:
          map['description']?.toString(),

      price:
          _parsePrice(map['price']),

      gallery:
          _parseGallery(map['gallery']),

      isActive:
          map['is_active'] == true,

      createdAt:
          _parseDate(map['created_at']),

      updatedAt:
          _parseDate(map['updated_at']),

      categoryId:
          categoryMap?['id']?.toString(),

      categoryName:
          categoryMap?['name']?.toString(),

      categorySlug:
          categoryMap?['slug']?.toString(),

      categoryParentId:
          categoryMap?['parent_id']
              ?.toString(),
    );
  }

  // ============================================================
  // TO MAP
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'category_node_id': categoryNodeId,
      'name': name,
      'slug': slug,
      'description': description,
      'price': price,
      'gallery': gallery,
      'is_active': isActive,
      'created_at':
          createdAt?.toIso8601String(),
      'updated_at':
          updatedAt?.toIso8601String(),
    };
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  ServiceModel copyWith({
    String? id,
    String? vendorId,
    String? categoryNodeId,
    String? name,
    String? slug,
    String? description,
    double? price,
    List<String>? gallery,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? categoryId,
    String? categoryName,
    String? categorySlug,
    String? categoryParentId,
  }) {
    return ServiceModel(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      categoryNodeId:
          categoryNodeId ??
              this.categoryNodeId,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description:
          description ?? this.description,
      price: price ?? this.price,
      gallery:
          gallery ?? this.gallery,
      isActive:
          isActive ?? this.isActive,
      createdAt:
          createdAt ?? this.createdAt,
      updatedAt:
          updatedAt ?? this.updatedAt,
      categoryId:
          categoryId ?? this.categoryId,
      categoryName:
          categoryName ?? this.categoryName,
      categorySlug:
          categorySlug ?? this.categorySlug,
      categoryParentId:
          categoryParentId ??
              this.categoryParentId,
    );
  }

  // ============================================================
  // PRICE
  // ============================================================

  static double _parsePrice(
    dynamic value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  // ============================================================
  // GALLERY
  // ============================================================

  static List<String> _parseGallery(
    dynamic value,
  ) {
    if (value is! List) {
      return [];
    }

    return value
        .map(
          (item) => item.toString(),
        )
        .where(
          (item) => item.isNotEmpty,
        )
        .toList();
  }

  // ============================================================
  // DATE
  // ============================================================

  static DateTime? _parseDate(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }
}