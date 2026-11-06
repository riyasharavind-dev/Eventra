class BusinessModel {
  final String id, vendorId, name;
  final String? description, logoUrl, bannerUrl, phone, email, address;
  final double? latitude, longitude;
  final String? shopAddress, shopStateId, shopDistrictId, shopSubdistrictId;

  final bool isActive;
  final DateTime createdAt, updatedAt;
  final String? whatsapp, websiteUrl, instagramUrl, primaryCategoryId;

  final bool travelsToCustomer;
  final int? startedYear;
  final String availabilityStatus;
  final List<Map<String, dynamic>> portfolio;

  const BusinessModel({
    required this.id,
    required this.vendorId,
    required this.name,
    this.description,
    this.logoUrl,
    this.bannerUrl,
    this.phone,
    this.email,
    this.address,
    this.shopAddress,
    this.shopStateId,
    this.shopDistrictId,
    this.shopSubdistrictId,

    this.latitude,
    this.longitude,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.whatsapp,
    this.websiteUrl,
    this.instagramUrl,
    this.primaryCategoryId,

    this.travelsToCustomer = true,
    this.startedYear,
    this.availabilityStatus = 'active',
    this.portfolio = const [],
  });

  factory BusinessModel.fromMap(Map<String, dynamic> map) => BusinessModel(
    id: map['id'] as String,
    vendorId: map['vendor_id'] as String,
    name: map['name'] as String,
    description: map['description'] as String?,
    logoUrl: map['logo_url'] as String?,
    bannerUrl: map['banner_url'] as String?,
    phone: map['phone'] as String?,
    email: map['email'] as String?,
    address: (map['shop_address'] ?? map['address']) as String?,
    shopAddress: (map['shop_address'] ?? map['address']) as String?,
    shopStateId: map['shop_state_id'] as String?,
    shopDistrictId: map['shop_district_id'] as String?,
    shopSubdistrictId: map['shop_subdistrict_id'] as String?,

    latitude: (map['latitude'] as num?)?.toDouble(),
    longitude: (map['longitude'] as num?)?.toDouble(),
    isActive: map['is_active'] as bool? ?? true,
    createdAt: DateTime.parse(map['created_at'].toString()),
    updatedAt: DateTime.parse(map['updated_at'].toString()),
    whatsapp: map['whatsapp'] as String?,
    websiteUrl: map['website_url'] as String?,
    instagramUrl: map['instagram_url'] as String?,
    primaryCategoryId: map['primary_category_id'] as String?,

    travelsToCustomer: map['travels_to_customer'] as bool? ?? true,
    startedYear: map['started_year'] as int?,
    availabilityStatus:
        map['availability_status'] as String? ??
        (map['is_active'] == false ? 'archived' : 'active'),
    portfolio: (map['portfolio'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
  );

  int? get yearsOfExperience =>
      startedYear == null ? null : DateTime.now().year - startedYear!;
  Map<String, dynamic> toMap() => {
    'id': id,
    'vendor_id': vendorId,
    'name': name,
    'description': description,
    'logo_url': logoUrl,
    'banner_url': bannerUrl,
    'phone': phone,
    'email': email,
    'address': shopAddress ?? address,
    'shop_address': shopAddress ?? address,
    'shop_state_id': shopStateId,
    'shop_district_id': shopDistrictId,
    'shop_subdistrict_id': shopSubdistrictId,

    'latitude': latitude,
    'longitude': longitude,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'whatsapp': whatsapp,
    'website_url': websiteUrl,
    'instagram_url': instagramUrl,
    'primary_category_id': primaryCategoryId,

    'travels_to_customer': travelsToCustomer,
    'started_year': startedYear,
    'availability_status': availabilityStatus,
    'portfolio': portfolio,
  };
}
