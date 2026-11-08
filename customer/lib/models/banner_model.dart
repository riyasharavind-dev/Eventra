class BannerModel {
  final String id;
  final String title;
  final String? subtitle;
  final String imageUrl;
  final String imagePath;
  final String actionType;
  final String? actionValue;
  final bool isActive;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BannerModel({
    required this.id,
    required this.title,
    this.subtitle,
    required this.imageUrl,
    required this.imagePath,
    required this.actionType,
    this.actionValue,
    required this.isActive,
    required this.sortOrder,
    this.createdAt,
    this.updatedAt,
  });

  factory BannerModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return BannerModel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      subtitle: map['subtitle']?.toString(),
      imageUrl: map['image_url']?.toString() ?? '',
      imagePath: map['image_path']?.toString() ?? '',
      actionType:
          map['action_type']?.toString() ?? 'none',
      actionValue:
          map['action_value']?.toString(),
      isActive:
          map['is_active'] == true,
      sortOrder:
          (map['sort_order'] as num?)?.toInt() ?? 0,
      createdAt:
          map['created_at'] != null
              ? DateTime.tryParse(
                  map['created_at'].toString(),
                )
              : null,
      updatedAt:
          map['updated_at'] != null
              ? DateTime.tryParse(
                  map['updated_at'].toString(),
                )
              : null,
    );
  }
}