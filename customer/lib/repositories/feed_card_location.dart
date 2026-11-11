import 'package:supabase_flutter/supabase_flutter.dart';

Future<Map<String, dynamic>> addCardLocations(
  SupabaseClient db,
  Map<String, dynamic> response,
) async {
  final items = <Map>[];
  void collect(Map payload) {
    for (final item in payload['items'] as List? ?? []) {
      if (item is Map) {
        items.add(item);
      }
    }
    for (final section in payload['sections'] as List? ?? []) {
      if (section is Map) {
        collect(section);
      }
    }
  }

  collect(response);
  if (items.isEmpty) return response;
  try {
    final locations = await db.rpc(
      'customer_card_display_metadata',
      params: {
        'p_items': [
          for (final item in items.take(100))
            {'id': item['id'], 'type': item['type'] ?? 'services'},
        ],
      },
    ) as Map;
    for (final item in items) {
      final metadata = locations['${item['type'] ?? 'services'}:${item['id']}'];
      if (metadata is Map) item.addAll(metadata);
    }
  } catch (_) {
    /* A location lookup failure must not block browsing. */
  }
  return response;
}
