import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/home_feed.dart';

class HomeFeedRepository {
  final SupabaseClient db;
  HomeFeedRepository({SupabaseClient? client})
    : db = client ?? Supabase.instance.client;
  Future<Map<String, dynamic>> page(
    int offset, {
    double? lat,
    double? lng,
  }) async => Map<String, dynamic>.from(
    await db.rpc(
      'home_feed_page',
      params: {'p_offset': offset, 'p_limit': 3, 'p_lat': lat, 'p_lng': lng},
    ) as Map,
  );
  Future<Map<String, dynamic>> items(
    String id,
    int offset, {
    double? lat,
    double? lng,
  }) async => Map<String, dynamic>.from(
    await db.rpc(
      'home_feed_items',
      params: {
        'p_section_id': id,
        'p_offset': offset,
        'p_limit': 20,
        'p_lat': lat,
        'p_lng': lng,
      },
    ) as Map,
  );
  Future<Map<String, dynamic>> vendorServices(String id, int offset) async =>
      Map<String, dynamic>.from(
        await db.rpc(
          'home_feed_vendor_services',
          params: {'p_vendor_id': id, 'p_offset': offset},
        ) as Map,
      );
  Future<Map<String, dynamic>?> location() async {
    final id = db.auth.currentUser?.id;
    if (id == null) return null;
    return db
        .from('customers')
        .select('latitude,longitude')
        .eq('id', id)
        .maybeSingle();
  }
}

class HomeFeedController extends ChangeNotifier {
  final HomeFeedRepository repository;
  HomeFeedController({HomeFeedRepository? repository})
    : repository = repository ?? HomeFeedRepository();
  final List<HomeFeedSection> sections = [];
  bool loading = false,
      hasMore = true,
      _disposed = false,
      _replaceOnSuccess = false;
  Object? error;
  double? lat, lng;
  int _offset = 0, _generation = 0;
  void emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    final request = ++_generation;
    _replaceOnSuccess = true;
    loading = true;
    error = null;
    emit();
    try {
      final position = await repository.location();
      if (_disposed || request != _generation) return;
      lat = (position?['latitude'] as num?)?.toDouble();
      lng = (position?['longitude'] as num?)?.toDouble();
    } catch (_) {
      lat = null;
      lng = null;
    }
    if (_disposed || request != _generation) return;
    _offset = 0;
    hasMore = true;
    loading = false;
    await loadMore(reset: true);
  }

  Future<void> loadMore({bool reset = false}) async {
    if (_disposed || loading || !hasMore) return;
    final request = _generation;
    loading = true;
    error = null;
    emit();
    try {
      final fresh = <HomeFeedSection>[];
      do {
        final response = await repository.page(_offset, lat: lat, lng: lng);
        if (_disposed || request != _generation) return;
        final next = (response['next_offset'] as num).toInt();
        hasMore = response['has_more'] == true && next > _offset;
        _offset = next;
        fresh.addAll(
          (response['sections'] as List)
              .map((e) => HomeFeedSection(Map<String, dynamic>.from(e as Map)))
              .where((s) => s.items.isNotEmpty),
        );
      } while (fresh.isEmpty && hasMore);
      if (reset || _replaceOnSuccess) {
        sections.clear();
        _replaceOnSuccess = false;
      }
      final ids = sections.map((s) => s.id).toSet();
      sections.addAll(fresh.where((s) => ids.add(s.id)));
    } catch (e) {
      if (request == _generation) error = e;
    } finally {
      if (!_disposed && request == _generation) {
        loading = false;
        emit();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
