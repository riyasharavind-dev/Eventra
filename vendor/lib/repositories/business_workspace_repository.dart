import '../models/shop_region_boundary.dart';
import '../models/administrative_region.dart';

import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/business_model.dart';

/// Business management operations. The original BusinessRepository remains
/// compatible with Me/dashboard reads; this screen uses atomic server saves.
class BusinessWorkspaceRepository {
  final SupabaseClient db;
  BusinessWorkspaceRepository({SupabaseClient? client})
    : db = client ?? Supabase.instance.client;
  String get uid =>
      db.auth.currentUser?.id ?? (throw StateError('Please sign in again.'));
  static String newId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<ShopRegionBoundary> boundary(String regionId) async =>
      ShopRegionBoundary.fromMap(
        Map<String, dynamic>.from(
          await db.rpc(
            'get_shop_region_boundary',
            params: {'p_region_id': regionId},
          ) as Map,
        ),
      );

  Future<List<AdministrativeRegion>> regions({
    required String level,
    String? parentId,
  }) async {
    var query = db
        .from('administrative_regions')
        .select()
        .eq('is_active', true)
        .eq('level', level);
    if (parentId != null) {
      query = query.eq('parent_id', parentId);
    }
    return (await query.order('name'))
        .map(AdministrativeRegion.fromMap)
        .toList();
  }

  Future<List<AdministrativeRegion>> regionDetails(List<String> ids) async {
    if (ids.isEmpty) return [];
    return (await db
            .from('administrative_regions')
            .select()
            .inFilter('id', ids))
        .map(AdministrativeRegion.fromMap)
        .toList();
  }

  Future<List<BusinessModel>> list() async {
    final rows = await db
        .from('businesses')
        .select()
        .eq('vendor_id', uid)
        .order('created_at');
    return rows.map(BusinessModel.fromMap).toList();
  }

  Future<BusinessModel> get(String id) async => BusinessModel.fromMap(
    await db
        .from('businesses')
        .select()
        .eq('id', id)
        .eq('vendor_id', uid)
        .single(),
  );
  Future<List<Map<String, dynamic>>> categories() async =>
      List<Map<String, dynamic>>.from(
        await db
            .from('category_nodes')
            .select('id,name,parent_id')
            .order('name'),
      );
  Future<List<String>> categoryIds(String id) async {
    final rows = await db
        .from('business_category_nodes')
        .select('category_node_id')
        .eq('business_id', id);
    return rows.map((r) => r['category_node_id'] as String).toList();
  }

  Future<BusinessModel> save(
    String id,
    Map<String, dynamic> data,
    List<String> ids,
  ) async {
    if (ids.length != 1 || data['primary_category_id'] != ids.single) {
      throw StateError('Select exactly one main business category.');
    }
    final result = await db.rpc(
      'save_vendor_business_location',
      params: {'p_id': id, 'p_data': data, 'p_categories': ids},
    );
    return BusinessModel.fromMap(Map<String, dynamic>.from(result as Map));
  }

  Future<BusinessModel> status(BusinessModel business, String status) async {
    final ids = await categoryIds(business.id);
    if (ids.isEmpty || business.primaryCategoryId == null) {
      throw StateError(
        'Edit this business and choose its categories and primary category first.',
      );
    }
    return BusinessModel.fromMap(
      Map<String, dynamic>.from(
        await db.rpc(
          'save_vendor_business',
          params: {
            'p_id': business.id,
            'p_data': {...business.toMap(), 'availability_status': status},
            'p_categories': ids,
          },
        ) as Map,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> services(String id) async =>
      List<Map<String, dynamic>>.from(
        await db
            .from('services')
            .select()
            .eq('vendor_id', uid)
            .eq('business_id', id)
            .order('created_at'),
      );
  Future<void> saveService(
    String id,
    String businessId,
    Map<String, dynamic> data,
  ) async {
    await db.rpc(
      'save_business_service',
      params: {'p_id': id, 'p_business_id': businessId, 'p_data': data},
    );
  }

  Future<Map<String, dynamic>?> verification(String id) => db
      .from('business_verifications')
      .select()
      .eq('business_id', id)
      .maybeSingle();
  Future<String> uploadImage(
    String businessId,
    XFile file, {
    bool document = false,
  }) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > 8 * 1024 * 1024) {
      throw StateError('Choose an image smaller than 8 MB.');
    }
    // Inspect bytes rather than trusting filename or picker MIME metadata.
    String extension, mime;
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      extension = 'jpg';
      mime = 'image/jpeg';
    } else if (bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71) {
      extension = 'png';
      mime = 'image/png';
    } else if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      extension = 'webp';
      mime = 'image/webp';
    } else {
      throw StateError('Choose a JPG, PNG or WebP image.');
    }
    final path = '$uid/$businessId/${newId()}.$extension';
    final bucket = db.storage.from(
      document ? 'business-documents' : 'business-media',
    );
    await bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mime),
    );
    return document ? path : bucket.getPublicUrl(path);
  }

  Future<void> submitVerification(String businessId, String path) async {
    await db.rpc(
      'submit_business_verification',
      params: {'p_business_id': businessId, 'p_path': path},
    );
  }
}
