class ServiceModel {
  final String id;
  final String vendorId;
  final String categoryNodeId;
  final String? eventTypeId;

  final String name;
  final String slug;
  final String? description;

  final double price;
  final List<String> gallery;

  final bool isActive;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined data
  final String? vendorName;
  final String? vendorEmail;

  final String? categoryName;
  final String? eventTypeName;

  const ServiceModel({
    required this.id,
    required this.vendorId,
    required this.categoryNodeId,
    this.eventTypeId,
    required this.name,
    required this.slug,
    this.description,
    required this.price,
    required this.gallery,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.vendorName,
    this.vendorEmail,
    this.categoryName,
    this.eventTypeName,
  });

  factory ServiceModel.fromMap(Map<String, dynamic> map) {
    final vendor = map['vendors'] is Map
        ? Map<String, dynamic>.from(map['vendors'])
        : null;

    final category = map['category_nodes'] is Map
        ? Map<String, dynamic>.from(map['category_nodes'])
        : null;

    final eventType = map['event_types'] is Map
        ? Map<String, dynamic>.from(map['event_types'])
        : null;

    final rawGallery = map['gallery'];

    final List<String> gallery = [];

    if (rawGallery is List) {
      for (final item in rawGallery) {
        if (item != null) {
          gallery.add(item.toString());
        }
      }
    }

    return ServiceModel(
      id: map['id']?.toString() ?? '',
      vendorId: map['vendor_id']?.toString() ?? '',
      categoryNodeId: map['category_node_id']?.toString() ?? '',
      eventTypeId: map['event_type_id']?.toString(),

      name: map['name']?.toString() ?? '',
      slug: map['slug']?.toString() ?? '',
      description: map['description']?.toString(),

      price: map['price'] is num
          ? (map['price'] as num).toDouble()
          : double.tryParse(
                map['price']?.toString() ?? '',
              ) ??
              0,

      gallery: gallery,

      isActive: map['is_active'] == true,

      createdAt: DateTime.tryParse(
        map['created_at']?.toString() ?? '',
      ),

      updatedAt: DateTime.tryParse(
        map['updated_at']?.toString() ?? '',
      ),

      vendorName: vendor?['name']?.toString(),
      vendorEmail: vendor?['email']?.toString(),

      categoryName: category?['name']?.toString(),

      eventTypeName: eventType?['name']?.toString(),
    );
  }
}