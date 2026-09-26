class AuthModel {
  final String id;
  final String email;
  final String name;
  final String role;
  final DateTime? createdAt;

  const AuthModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.createdAt,
  });

  factory AuthModel.fromMap(Map<String, dynamic> map) {
    return AuthModel(
      id: map['id'] as String,
      email: map['email'] as String,
      name: map['name'] as String,
      role: map['role'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}