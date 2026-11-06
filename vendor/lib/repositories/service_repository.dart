import '../models/service_pricing.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/service_model.dart';

class ServiceRepository {
  final SupabaseClient _supabase;

  ServiceRepository({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  // ============================================================
  // SERVICE SELECT
  // ============================================================

  static const String _serviceSelect = '''
    id,
    vendor_id,
    business_id,
    category_node_id,
    event_type_id,
    name,
    slug,
    description,
    price,
    pricing_type,
    pricing_unit,
    gallery,
    is_active,
    created_at,
    updated_at,
    category_nodes (
      id,
      name,
      slug,
      parent_id
    )
  ''';

  // ============================================================
  // CURRENT USER
  // ============================================================

  String _requireUserId() {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('You are not logged in.');
    }

    return user.id;
  }

  // ============================================================
  // GET MY SERVICES
  // ============================================================

  Future<List<ServiceModel>> getMyServices() async {
    final String userId = _requireUserId();

    final response = await _supabase
        .from('services')
        .select(_serviceSelect)
        .eq('vendor_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => ServiceModel.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  // ============================================================
  // GET SERVICE BY ID
  // ============================================================

  Future<ServiceModel?> getServiceById(String serviceId) async {
    final String userId = _requireUserId();

    final response = await _supabase
        .from('services')
        .select(_serviceSelect)
        .eq('id', serviceId)
        .eq('vendor_id', userId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return ServiceModel.fromMap(Map<String, dynamic>.from(response));
  }

  // ============================================================
  // GET ACTIVE SERVICES
  // ============================================================

  Future<List<ServiceModel>> getActiveServices() async {
    final String userId = _requireUserId();

    final response = await _supabase
        .from('services')
        .select(_serviceSelect)
        .eq('vendor_id', userId)
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => ServiceModel.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  // ============================================================
  // CREATE SERVICE
  // ============================================================

  Future<ServiceModel> createService({
    required String name,
    required String categoryNodeId,
    required String slug,
    String? businessId,
    String? eventTypeId,
    String? description,
    ServicePricing? pricing,
    required double price,
    List<String> gallery = const [],
  }) async {
    final String userId = _requireUserId();

    final selectedPricing = pricing ?? const ServicePricing();
    selectedPricing.validate(price);
    final Map<String, dynamic> data = {
      'vendor_id': userId,
      'business_id': businessId,
      'category_node_id': categoryNodeId,
      'event_type_id': eventTypeId,
      'name': name,
      'slug': slug,
      'description': description,
      'price': price,
      ...selectedPricing.toMap(),
      'gallery': gallery,
      'is_active': true,
    };

    final response = await _supabase
        .from('services')
        .insert(data)
        .select(_serviceSelect)
        .single();

    return ServiceModel.fromMap(Map<String, dynamic>.from(response));
  }

  // ============================================================
  // UPDATE SERVICE
  // ============================================================

  Future<ServiceModel> updateService({
    required ServiceModel service,
    required String name,
    required String categoryNodeId,
    String? businessId,
    String? eventTypeId,
    String? description,
    ServicePricing? pricing,
    required double price,
    required List<String> gallery,
  }) async {
    final String userId = _requireUserId();

    final selectedPricing = pricing ?? service.pricing;
    selectedPricing.validate(price);
    final Map<String, dynamic> data = {
      'name': name,
      'business_id': businessId,
      'category_node_id': categoryNodeId,
      'event_type_id': eventTypeId,
      'description': description,
      'price': price,
      ...selectedPricing.toMap(),
      'gallery': gallery,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final response = await _supabase
        .from('services')
        .update(data)
        .eq('id', service.id)
        .eq('vendor_id', userId)
        .select(_serviceSelect)
        .single();

    return ServiceModel.fromMap(Map<String, dynamic>.from(response));
  }

  // ============================================================
  // TOGGLE SERVICE STATUS
  // ============================================================

  Future<ServiceModel> toggleServiceStatus(ServiceModel service) async {
    final String userId = _requireUserId();

    final bool newStatus = !service.isActive;

    final response = await _supabase
        .from('services')
        .update({
          'is_active': newStatus,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', service.id)
        .eq('vendor_id', userId)
        .select(_serviceSelect)
        .single();

    return ServiceModel.fromMap(Map<String, dynamic>.from(response));
  }

  // ============================================================
  // DELETE SERVICE
  // ============================================================

  Future<void> deleteService(ServiceModel service) async {
    final String userId = _requireUserId();

    final ServiceModel? existing = await getServiceById(service.id);

    if (existing == null) {
      throw Exception(
        'Service not found or you do not have permission to delete it.',
      );
    }

    // ----------------------------------------------------------
    // Delete gallery files
    // ----------------------------------------------------------

    if (service.gallery.isNotEmpty) {
      final List<String> paths = [];

      for (final String url in service.gallery) {
        final String? path = _extractStoragePath(url);

        if (path != null && path.isNotEmpty) {
          paths.add(path);
        }
      }

      if (paths.isNotEmpty) {
        try {
          await _supabase.storage.from('service-gallery').remove(paths);
        } catch (_) {
          // Continue with database deletion.
        }
      }
    }

    // ----------------------------------------------------------
    // Delete database record
    // ----------------------------------------------------------

    await _supabase
        .from('services')
        .delete()
        .eq('id', service.id)
        .eq('vendor_id', userId);
  }

  // ============================================================
  // DELETE SINGLE GALLERY IMAGE
  // ============================================================

  Future<void> deleteGalleryImage({
    required String serviceId,
    required String imageUrl,
  }) async {
    final ServiceModel? service = await getServiceById(serviceId);

    if (service == null) {
      throw Exception('Service not found.');
    }

    final List<String> gallery = List<String>.from(service.gallery);

    if (!gallery.contains(imageUrl)) {
      return;
    }

    gallery.remove(imageUrl);

    final String userId = _requireUserId();

    await _supabase
        .from('services')
        .update({
          'gallery': gallery,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', serviceId)
        .eq('vendor_id', userId);

    final String? path = _extractStoragePath(imageUrl);

    if (path != null && path.isNotEmpty) {
      try {
        await _supabase.storage.from('service-gallery').remove([path]);
      } catch (_) {
        // Database update already succeeded.
      }
    }
  }

  // ============================================================
  // EXTRACT STORAGE PATH
  // ============================================================

  String? _extractStoragePath(String url) {
    try {
      final Uri uri = Uri.parse(url);

      const String marker = '/storage/v1/object/public/service-gallery/';

      final String fullUrl = uri.toString();

      final int index = fullUrl.indexOf(marker);

      if (index == -1) {
        return null;
      }

      String path = fullUrl.substring(index + marker.length);

      // Remove query parameters such as
      // cache-busting values if present.
      final int queryIndex = path.indexOf('?');

      if (queryIndex != -1) {
        path = path.substring(0, queryIndex);
      }

      return Uri.decodeComponent(path);
    } catch (_) {
      return null;
    }
  }
}
