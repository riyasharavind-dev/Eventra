import 'service_pricing.dart';

class ServiceModel {
  final String id;
  final String vendorId;

  final String? businessId;
  final String categoryNodeId;
  final String? eventTypeId;

  final String name;
  final String slug;
  final String? description;

  final ServicePricing pricing;
  String get priceLabel => pricing.format(price);
  final double price;
  final List<String> gallery;

  final bool isActive;

  final String? categoryName;
  final String? categorySlug;
  final String? categoryParentId;

  final DateTime createdAt;
  final DateTime updatedAt;

  const ServiceModel({
    required this.id,
    required this.vendorId,
    this.businessId,
    required this.categoryNodeId,
    this.eventTypeId,
    required this.name,
    required this.slug,
    this.description,
    this.pricing = const ServicePricing(),
    required this.price,
    required this.gallery,
    required this.isActive,
    this.categoryName,
    this.categorySlug,
    this.categoryParentId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ServiceModel.fromMap(Map<String, dynamic> map) {
    final dynamic rawGallery = map['gallery'];

    final List<String> gallery;

    if (rawGallery is List) {
      gallery = rawGallery
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList();
    } else {
      gallery = [];
    }

    final dynamic rawCategory = map['category_nodes'];

    String? categoryName;
    String? categorySlug;
    String? categoryParentId;

    if (rawCategory is Map) {
      categoryName = rawCategory['name']?.toString();

      categorySlug = rawCategory['slug']?.toString();

      categoryParentId = rawCategory['parent_id']?.toString();
    }

    return ServiceModel(
      id: map['id'].toString(),

      vendorId: map['vendor_id'].toString(),

      businessId: map['business_id']?.toString(),

      categoryNodeId: map['category_node_id'].toString(),

      eventTypeId: map['event_type_id']?.toString(),

      name: map['name']?.toString() ?? '',

      slug: map['slug']?.toString() ?? '',

      description: map['description']?.toString(),

      pricing: ServicePricing.fromMap(map),
      price: _parseDouble(map['price']),

      gallery: gallery,

      isActive: map['is_active'] == true,

      categoryName: categoryName,

      categorySlug: categorySlug,

      categoryParentId: categoryParentId,

      createdAt: _parseDateTime(map['created_at']),

      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'business_id': businessId,
      'category_node_id': categoryNodeId,
      'event_type_id': eventTypeId,
      'name': name,
      'slug': slug,
      'description': description,
      'price': price,
      ...pricing.toMap(),
      'gallery': gallery,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ServiceModel copyWith({
    String? id,
    String? vendorId,
    String? businessId,
    String? categoryNodeId,
    String? eventTypeId,
    String? name,
    String? slug,
    String? description,
    double? price,
    ServicePricing? pricing,
    List<String>? gallery,
    bool? isActive,
    String? categoryName,
    String? categorySlug,
    String? categoryParentId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiceModel(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      businessId: businessId ?? this.businessId,
      categoryNodeId: categoryNodeId ?? this.categoryNodeId,
      eventTypeId: eventTypeId ?? this.eventTypeId,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      pricing: pricing ?? this.pricing,
      price: price ?? this.price,
      gallery: gallery ?? this.gallery,
      isActive: isActive ?? this.isActive,
      categoryName: categoryName ?? this.categoryName,
      categorySlug: categorySlug ?? this.categorySlug,
      categoryParentId: categoryParentId ?? this.categoryParentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }

    return DateTime.parse(value.toString());
  }
}
