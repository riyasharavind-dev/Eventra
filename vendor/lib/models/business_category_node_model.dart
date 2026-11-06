class BusinessCategoryNodeModel {
  final String id;
  final String businessId;
  final String categoryNodeId;
  final DateTime createdAt;

  const BusinessCategoryNodeModel({
    required this.id,
    required this.businessId,
    required this.categoryNodeId,
    required this.createdAt,
  });

  factory BusinessCategoryNodeModel.fromMap(Map<String, dynamic> map) {
    return BusinessCategoryNodeModel(
      id: map['id'],
      businessId: map['business_id'],
      categoryNodeId: map['category_node_id'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'category_node_id': categoryNodeId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}