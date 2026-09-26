class VendorModel {
  final String id;
  final String name;
  final String email;
  final DateTime? createdAt;

  const VendorModel({
    required this.id,
    required this.name,
    required this.email,
    this.createdAt,
  });

  factory VendorModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return VendorModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      createdAt: DateTime.tryParse(
        map['created_at']?.toString() ?? '',
      ),
    );
  }
}