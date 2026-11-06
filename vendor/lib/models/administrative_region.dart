class AdministrativeRegion {
  final String id, name, level;
  final String? parentId;
  final double? latitude, longitude;
  const AdministrativeRegion({
    required this.id,
    required this.name,
    required this.level,
    this.parentId,
    this.latitude,
    this.longitude,
  });
  factory AdministrativeRegion.fromMap(Map<String, dynamic> row) =>
      AdministrativeRegion(
        id: row['id'] as String,
        name: row['name'] as String,
        level: row['level'] as String,
        parentId: row['parent_id'] as String?,
        latitude: (row['latitude'] as num?)?.toDouble(),
        longitude: (row['longitude'] as num?)?.toDouble(),
      );
}
