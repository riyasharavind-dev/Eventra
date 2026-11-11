import 'feed_card_location.dart';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/home_feed.dart';
import '../models/service_recommendations.dart';

class RecommendationRepository {
  final SupabaseClient db;
  RecommendationRepository({SupabaseClient? client})
    : db = client ?? Supabase.instance.client;
  static final changes = ValueNotifier<int>(0);

  Future<RecommendationPage> page({String? serviceId, int offset = 0}) async =>
      RecommendationPage(
        await addCardLocations(
          db,
          Map<String, dynamic>.from(
            await db.rpc(
              'customer_recommendations',
              params: {
                'p_service_id': serviceId,
                'p_offset': offset,
                'p_limit': 12,
              },
            ) as Map,
          ),
        ),
      );

  Future<RecommendationPage> relatedVendorsPage({
    required String serviceId,
    int offset = 0,
  }) async => RecommendationPage(
    Map<String, dynamic>.from(
      await db.rpc(
        'customer_related_vendors',
        params: {'p_service_id': serviceId, 'p_offset': offset, 'p_limit': 12},
      ) as Map,
    ),
  );

  /// Discovery signals must never block saving, viewing, or booking a service.
  Future<void> signal(String serviceId, String action) async {
    if (db.auth.currentUser == null) return;
    try {
      await db.rpc(
        'customer_service_signal',
        params: {'p_service_id': serviceId, 'p_action': action},
      );
      changes.value++;
    } catch (_) {
      // Offline browsing and local favorites remain usable. No retry queue
      // containing another account's activity survives a sign-out.
    }
  }
}

class RecommendationController extends ChangeNotifier {
  final RecommendationRepository repository;
  final String? serviceId;
  final bool vendors;
  RecommendationController({
    required this.repository,
    this.serviceId,
    this.vendors = false,
  });
  final items = <HomeFeedItem>[];
  bool loading = false, hasMore = true, personalized = false;
  Object? error;
  int _offset = 0, _generation = 0;
  bool _disposed = false, _replaceOnSuccess = false;

  Future<void> refresh() async {
    if (_disposed) return;
    _generation++;
    _replaceOnSuccess = true;
    loading = false;
    hasMore = true;
    _offset = 0;
    await _load(replace: true);
  }

  Future<void> loadMore() => _load();
  Future<void> _load({bool replace = false}) async {
    if (_disposed || loading || !hasMore) return;
    final request = _generation;
    final offset = _offset;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final page = vendors
          ? await repository.relatedVendorsPage(
              serviceId: serviceId!,
              offset: offset,
            )
          : await repository.page(serviceId: serviceId, offset: offset);
      if (_disposed || request != _generation) return;
      if (replace || _replaceOnSuccess) {
        items.clear();
        _replaceOnSuccess = false;
      }
      final ids = items.map((e) => e.id).toSet();
      items.addAll(page.items.where((e) => ids.add(e.id)));
      hasMore =
          page.hasMore && page.nextOffset > offset && page.nextOffset <= 200;
      _offset = page.nextOffset;
      personalized = page.personalized;
    } catch (e) {
      if (!_disposed && request == _generation) error = e;
    } finally {
      if (!_disposed && request == _generation) {
        loading = false;
        notifyListeners();
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
