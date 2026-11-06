class AdminConnections {
  final List<DatabaseConnection> sources;
  final List<StorageConnection> buckets;
  final List<Map<String, dynamic>> relationships;
  const AdminConnections({
    required this.sources,
    required this.buckets,
    this.relationships = const [],
  });
  factory AdminConnections.fromMap(Map<String, dynamic> m) => AdminConnections(
    sources: (m['sources'] as List)
        .map((x) => DatabaseConnection(Map<String, dynamic>.from(x as Map)))
        .toList(),
    buckets: (m['buckets'] as List)
        .map((x) => StorageConnection(Map<String, dynamic>.from(x as Map)))
        .toList(),
    relationships: (m['relationships'] as List? ?? [])
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList(),
  );
}

class DatabaseConnection {
  final Map<String, dynamic> data;
  const DatabaseConnection(this.data);
  String get schema => data['schema'] as String;
  String get name => data['name'] as String;
  String get key => '$schema.$name';
  String get label => data['label'] as String;
  String get section => data['section'] as String;
  String? get module => data['module'] as String?;
  String get kind => data['kind'] as String;
  int get rows => (data['rows'] as num).toInt();
  bool get rls => data['rls'] == true;
  bool get invoker => data['invoker'] == true;
}

class StorageConnection {
  final Map<String, dynamic> data;
  const StorageConnection(this.data);
  String get id => data['id'] as String;
  bool get isPublic => data['public'] == true;
  int get objects => (data['objects'] as num).toInt();
  int get bytes => (data['bytes'] as num? ?? 0).toInt();
  int? get maxBytes => (data['max_bytes'] as num?)?.toInt();
  List<String> get mimeTypes =>
      List<String>.from(data['mime_types'] as List? ?? []);
  String get module =>
      const {
        'profile': 'vendors',
        'profile-images': 'customers',
        'banners': 'banners',
        'service-gallery': 'services',
        'business-media': 'businesses',
        'business-documents': 'business_verifications',
        'vendor-verification-documents': 'verification_documents',
        'support-attachments': 'support_tickets',
        'social-icons': 'social_links',
      }[id] ??
      'admin_storage_cleanup';
  String get purpose =>
      const {
        'profile': 'Vendor profile images',
        'profile-images': 'Customer profile images',
        'banners': 'Customer app promotional banners',
        'service-gallery': 'Service listing photos',
        'business-media': 'Business logos and banners',
        'business-documents': 'Private business verification proof',
        'vendor-verification-documents': 'Private vendor verification proof',
        'support-attachments': 'Private support screenshots',
        'social-icons': 'Follow Us icons',
      }[id] ??
      'Platform storage';
}

String adminBytes(int? value) {
  if (value == null) return 'Not configured';
  if (value < 1024) return '$value B';
  if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
  return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
}
