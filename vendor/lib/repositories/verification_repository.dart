
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/verification_model.dart';

class VerificationRepository {
  final SupabaseClient _client;

  VerificationRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static const String _identityTable = 'vendor_identity_verifications';
  static const String _verificationTable = 'vendor_verifications';
  static const String _documentsTable = 'verification_documents';

  /// Fetch all verification information for one vendor.
  /// Returns null if no verification records exist yet.
  Future<VerificationModel?> getVerification(String vendorId) async {
    final results = await Future.wait([
      _client
          .from(_identityTable)
          .select()
          .eq('vendor_id', vendorId)
          .maybeSingle(),
      _client
          .from(_verificationTable)
          .select()
          .eq('vendor_id', vendorId)
          .maybeSingle(),
      _client
          .from(_documentsTable)
          .select()
          .eq('vendor_id', vendorId)
          .order('created_at', ascending: false),
    ]);

    final identityMap = results[0] as Map<String, dynamic>?;
    final overallMap = results[1] as Map<String, dynamic>?;
    final documentMaps =
        (results[2] as List).cast<Map<String, dynamic>>();

    if (identityMap == null && overallMap == null && documentMaps.isEmpty) {
      return null;
    }

    // Missing records are represented by defaults in memory.
    return VerificationModel.fromMaps(
      identityMap: identityMap ??
          {
            'vendor_id': vendorId,
            'status': 'not_started',
          },
      overallMap: overallMap ??
          {
            'vendor_id': vendorId,
            'status': 'not_started',
          },
      documentMaps: documentMaps,
    );
  }

  /// Create or update identity verification metadata.
  Future<void> saveIdentityVerification(
    VendorIdentityVerification verification,
  ) async {
    await _client.from(_identityTable).upsert(
          verification.toMap(),
          onConflict: 'vendor_id',
        );
  }

  /// Create or update the vendor's overall verification status.
  Future<void> saveOverallVerification(
    VendorVerification verification,
  ) async {
    await _client.from(_verificationTable).upsert(
          verification.toMap(),
          onConflict: 'vendor_id',
        );
  }

  /// Register a document or update an existing document record.
  /// This saves metadata only; it does not upload the actual file.
  Future<String> saveDocument(
    VerificationDocument document,
  ) async {
    final data = document.toMap();

    if (document.id == null) {
      final result = await _client
          .from(_documentsTable)
          .insert(data)
          .select('id')
          .single();

      return result['id'].toString();
    }

    await _client
        .from(_documentsTable)
        .update(data)
        .eq('id', document.id!)
        .eq('vendor_id', document.vendorId);

    return document.id!;
  }

  /// Get all documents for a vendor.
  Future<List<VerificationDocument>> getDocuments(
    String vendorId,
  ) async {
    final response = await _client
        .from(_documentsTable)
        .select()
        .eq('vendor_id', vendorId)
        .order('created_at', ascending: false);

    return (response as List)
        .map(
          (item) => VerificationDocument.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  /// Get documents for a particular business owned by the vendor.
  Future<List<VerificationDocument>> getBusinessDocuments({
    required String vendorId,
    required String businessId,
  }) async {
    final response = await _client
        .from(_documentsTable)
        .select()
        .eq('vendor_id', vendorId)
        .eq('business_id', businessId)
        .order('created_at', ascending: false);

    return (response as List)
        .map(
          (item) => VerificationDocument.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  /// Update a document's status.
  Future<void> updateDocumentStatus({
    required String documentId,
    required String vendorId,
    required String status,
    String? rejectionReason,
  }) async {
    await _client
        .from(_documentsTable)
        .update({
          'status': status,
          'rejection_reason': rejectionReason,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', documentId)
        .eq('vendor_id', vendorId);
  }

  /// Update the overall verification status.
  Future<void> updateOverallStatus({
    required String vendorId,
    required String status,
    String? reviewNote,
    String? rejectionReason,
    String? reviewedBy,
  }) async {
    await _client.from(_verificationTable).upsert({
      'vendor_id': vendorId,
      'status': status,
      'review_note': reviewNote,
      'rejection_reason': rejectionReason,
      'reviewed_by': reviewedBy,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'vendor_id');
  }

  /// Delete a document record.
  /// Storage object deletion must be handled separately.
  Future<void> deleteDocument({
    required String documentId,
    required String vendorId,
  }) async {
    await _client
        .from(_documentsTable)
        .delete()
        .eq('id', documentId)
        .eq('vendor_id', vendorId);
  }
}
