class CustomerModel {
  final String id;
  final String name;
  final String email;
  final DateTime? createdAt;

  const CustomerModel({
    required this.id,
    required this.name,
    required this.email,
    this.createdAt,
  });

  factory CustomerModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return CustomerModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(
              map['created_at'].toString(),
            ),
    );
  }
}