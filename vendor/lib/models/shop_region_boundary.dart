import 'package:latlong2/latlong.dart';

/// GeoJSON polygons retain separate islands and exclusion holes.
class ShopRegionBoundary {
  final String id, name, sourceUrl;
  final int sourceYear;
  final LatLng center;
  final List<List<List<LatLng>>> polygons;
  const ShopRegionBoundary({
    required this.id,
    required this.name,
    required this.center,
    required this.polygons,
    required this.sourceUrl,
    required this.sourceYear,
  });
  factory ShopRegionBoundary.fromMap(Map<String, dynamic> data) {
    final geo = Map<String, dynamic>.from(data['geometry'] as Map);
    final coordinates = geo['coordinates'] as List;
    final raw = geo['type'] == 'Polygon' ? [coordinates] : coordinates;
    final center = data['center'] as List;
    final polygons = raw
        .map(
          (p) => (p as List)
              .map(
                (ring) => (ring as List)
                    .map(
                      (v) => LatLng(
                        (v[1] as num).toDouble(),
                        (v[0] as num).toDouble(),
                      ),
                    )
                    .toList(),
              )
              .toList(),
        )
        .toList();
    if (!['Polygon', 'MultiPolygon'].contains(geo['type']) ||
        polygons.isEmpty ||
        polygons.any((p) => p.isEmpty || p.any((r) => r.length < 4))) {
      throw const FormatException('Invalid region border');
    }
    return ShopRegionBoundary(
      id: data['id'] as String,
      name: data['name'] as String,
      center: LatLng(
        (center[0] as num).toDouble(),
        (center[1] as num).toDouble(),
      ),
      polygons: polygons,
      sourceUrl: data['source_url'] as String,
      sourceYear: (data['source_year'] as num).toInt(),
    );
  }
  Iterable<LatLng> get points => polygons.expand((p) => p.first);

  bool contains(LatLng point) {
    if (!point.latitude.isFinite || !point.longitude.isFinite) return false;
    for (final polygon in polygons) {
      final outer = _ring(point, polygon.first);
      if (outer == 0) continue;
      if (outer == 2) return true;
      var inHole = false;
      for (final hole in polygon.skip(1)) {
        final hit = _ring(point, hole);
        if (hit == 2) {
          return true; // Boundary edges are allowed, matching ST_Covers.
        }
        if (hit == 1) {
          inHole = true;
          break;
        }
      }
      if (!inHole) return true;
    }
    return false;
  }

  // 0 outside, 1 inside, 2 exactly on an edge.
  static int _ring(LatLng p, List<LatLng> ring) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final a = ring[j], b = ring[i];
      final dx = b.longitude - a.longitude, dy = b.latitude - a.latitude;
      final cross =
          (p.longitude - a.longitude) * dy - (p.latitude - a.latitude) * dx;
      if (cross.abs() < 1e-10 &&
          p.longitude >=
              (a.longitude < b.longitude ? a.longitude : b.longitude) - 1e-10 &&
          p.longitude <=
              (a.longitude > b.longitude ? a.longitude : b.longitude) + 1e-10 &&
          p.latitude >=
              (a.latitude < b.latitude ? a.latitude : b.latitude) - 1e-10 &&
          p.latitude <=
              (a.latitude > b.latitude ? a.latitude : b.latitude) + 1e-10) {
        return 2;
      }
      if ((a.latitude > p.latitude) != (b.latitude > p.latitude) &&
          p.longitude < dx * (p.latitude - a.latitude) / dy + a.longitude) {
        inside = !inside;
      }
    }
    return inside ? 1 : 0;
  }
}
