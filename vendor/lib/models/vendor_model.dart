class VendorModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? aboutMe;
  final String? preferredContactLanguage;
  final String? profileImageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const VendorModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.aboutMe,
    this.preferredContactLanguage,
    this.profileImageUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory VendorModel.fromMap(Map<String, dynamic> map) {
    return VendorModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString(),
      aboutMe: map['about_me']?.toString(),
      preferredContactLanguage: map['preferred_contact_language']?.toString(),
      profileImageUrl: map['profile_image_url']?.toString(),
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'about_me': aboutMe,
      'preferred_contact_language': preferredContactLanguage,
      'profile_image_url': profileImageUrl,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  VendorModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? aboutMe,
    String? preferredContactLanguage,
    String? profileImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VendorModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      aboutMe: aboutMe ?? this.aboutMe,
      preferredContactLanguage:
          preferredContactLanguage ?? this.preferredContactLanguage,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    return DateTime.tryParse(value.toString());
  }
}
