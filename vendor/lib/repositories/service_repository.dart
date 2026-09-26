import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/service_model.dart';

class ServiceRepository {
  final SupabaseClient _supabase;

  ServiceRepository({
    SupabaseClient? supabase,
  }) : _supabase =
            supabase ??
            Supabase.instance.client;

  // ============================================================
  // SERVICE SELECT
  // ============================================================

  static const String _serviceSelect = '''
    id,
    vendor_id,
    category_node_id,
    name,
    slug,
    description,
    price,
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
    final user =
        _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'You are not logged in.',
      );
    }

    return user.id;
  }

  // ============================================================
  // GET CURRENT VENDOR SERVICES
  // ============================================================

  Future<List<ServiceModel>>
      getMyServices() async {
    final String userId =
        _requireUserId();

    final response = await _supabase
        .from('services')
        .select(_serviceSelect)
        .eq(
          'vendor_id',
          userId,
        )
        .order(
          'created_at',
          ascending: false,
        );

    return (response as List)
        .map(
          (item) =>
              ServiceModel.fromMap(
            Map<String, dynamic>.from(
              item,
            ),
          ),
        )
        .toList();
  }

  // ============================================================
  // GET SERVICE BY ID
  // ============================================================

  Future<ServiceModel?>
      getServiceById(
    String serviceId,
  ) async {
    final String userId =
        _requireUserId();

    final response = await _supabase
        .from('services')
        .select(_serviceSelect)
        .eq(
          'id',
          serviceId,
        )
        .eq(
          'vendor_id',
          userId,
        )
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return ServiceModel.fromMap(
      Map<String, dynamic>.from(
        response,
      ),
    );
  }

  // ============================================================
  // CREATE SERVICE
  // ============================================================
  //
  // AddServiceDialog currently creates the service directly.
  // This method is available if you later want to move
  // creation completely into the repository.
  // ============================================================

  Future<ServiceModel>
      createService({
    required String name,
    required String categoryNodeId,
    required String slug,
    String? description,
    required double price,
    List<String> gallery =
        const [],
  }) async {
    final String userId =
        _requireUserId();

    final response = await _supabase
        .from('services')
        .insert({
          'vendor_id': userId,
          'category_node_id':
              categoryNodeId,
          'name': name,
          'slug': slug,
          'description': description,
          'price': price,
          'gallery': gallery,
          'is_active': true,
        })
        .select(_serviceSelect)
        .single();

    return ServiceModel.fromMap(
      Map<String, dynamic>.from(
        response,
      ),
    );
  }

  // ============================================================
  // UPDATE SERVICE
  // ============================================================

  Future<ServiceModel>
      updateService({
    required ServiceModel service,
    required String name,
    required String categoryNodeId,
    String? description,
    required double price,
    required List<String> gallery,
  }) async {
    final String userId =
        _requireUserId();

    final response = await _supabase
        .from('services')
        .update({
          'name': name,
          'category_node_id':
              categoryNodeId,
          'description': description,
          'price': price,
          'gallery': gallery,
          'updated_at':
              DateTime.now()
                  .toUtc()
                  .toIso8601String(),
        })
        .eq(
          'id',
          service.id,
        )
        .eq(
          'vendor_id',
          userId,
        )
        .select(_serviceSelect)
        .single();

    return ServiceModel.fromMap(
      Map<String, dynamic>.from(
        response,
      ),
    );
  }

  // ============================================================
  // TOGGLE SERVICE STATUS
  // ============================================================

  Future<ServiceModel>
      toggleServiceStatus(
    ServiceModel service,
  ) async {
    final String userId =
        _requireUserId();

    final bool newStatus =
        !service.isActive;

    final response = await _supabase
        .from('services')
        .update({
          'is_active': newStatus,
          'updated_at':
              DateTime.now()
                  .toUtc()
                  .toIso8601String(),
        })
        .eq(
          'id',
          service.id,
        )
        .eq(
          'vendor_id',
          userId,
        )
        .select(_serviceSelect)
        .single();

    return ServiceModel.fromMap(
      Map<String, dynamic>.from(
        response,
      ),
    );
  }

  // ============================================================
  // DELETE SERVICE
  // ============================================================

  Future<void> deleteService(
    ServiceModel service,
  ) async {
    final String userId =
        _requireUserId();

    // ----------------------------------------------------------
    // Verify ownership first
    // ----------------------------------------------------------

    final ServiceModel? existing =
        await getServiceById(
      service.id,
    );

    if (existing == null) {
      throw Exception(
        'Service not found or you do not have permission to delete it.',
      );
    }

    // ----------------------------------------------------------
    // Delete gallery files
    // ----------------------------------------------------------

    if (service.gallery.isNotEmpty) {
      final List<String> paths =
          [];

      for (final String url
          in service.gallery) {
        final String? path =
            _extractStoragePath(url);

        if (path != null &&
            path.isNotEmpty) {
          paths.add(path);
        }
      }

      if (paths.isNotEmpty) {
        try {
          await _supabase.storage
              .from('service-gallery')
              .remove(paths);
        } catch (_) {
          // Continue with database
          // deletion even if a storage
          // file is already missing.
        }
      }
    }

    // ----------------------------------------------------------
    // Delete database record
    // ----------------------------------------------------------

    await _supabase
        .from('services')
        .delete()
        .eq(
          'id',
          service.id,
        )
        .eq(
          'vendor_id',
          userId,
        );
  }

  // ============================================================
  // DELETE SINGLE GALLERY IMAGE
  // ============================================================
  //
  // Useful later if you want the edit screen to immediately
  // delete an image instead of waiting for Save Changes.
  // ============================================================

  Future<void>
      deleteGalleryImage({
    required String serviceId,
    required String imageUrl,
  }) async {
    final ServiceModel? service =
        await getServiceById(
      serviceId,
    );

    if (service == null) {
      throw Exception(
        'Service not found.',
      );
    }

    final List<String> gallery =
        List<String>.from(
      service.gallery,
    );

    if (!gallery.contains(
      imageUrl,
    )) {
      return;
    }

    gallery.remove(
      imageUrl,
    );

    final String userId =
        _requireUserId();

    await _supabase
        .from('services')
        .update({
          'gallery': gallery,
          'updated_at':
              DateTime.now()
                  .toUtc()
                  .toIso8601String(),
        })
        .eq(
          'id',
          serviceId,
        )
        .eq(
          'vendor_id',
          userId,
        );

    final String? path =
        _extractStoragePath(
      imageUrl,
    );

    if (path != null &&
        path.isNotEmpty) {
      try {
        await _supabase.storage
            .from('service-gallery')
            .remove([path]);
      } catch (_) {
        // Database update already
        // succeeded, so don't fail the
        // whole operation because the
        // storage object is missing.
      }
    }
  }

  // ============================================================
  // EXTRACT STORAGE PATH
  // ============================================================

  String? _extractStoragePath(
    String url,
  ) {
    try {
      final Uri uri =
          Uri.parse(url);

      const String marker =
          '/storage/v1/object/public/service-gallery/';

      final String fullUrl =
          uri.toString();

      final int index =
          fullUrl.indexOf(marker);

      if (index == -1) {
        return null;
      }

      return Uri.decodeComponent(
        fullUrl.substring(
          index + marker.length,
        ),
      );
    } catch (_) {
      return null;
    }
  }
}