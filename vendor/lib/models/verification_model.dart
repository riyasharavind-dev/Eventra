
class VerificationModel {
  final VendorIdentityVerification identity;
  final VendorVerification overall;
  final List<VerificationDocument> documents;

  const VerificationModel({
    required this.identity,
    required this.overall,
    required this.documents,
  });

  factory VerificationModel.fromMaps({
    required Map<String, dynamic> identityMap,
    required Map<String, dynamic> overallMap,
    required List<Map<String, dynamic>> documentMaps,
  }) {
    return VerificationModel(
      identity: VendorIdentityVerification.fromMap(identityMap),
      overall: VendorVerification.fromMap(overallMap),
      documents: documentMaps
          .map(VerificationDocument.fromMap)
          .toList(),
    );
  }
}

DateTime? _dateFrom(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

String? _stringFrom(dynamic value) {
  if (value == null) return null;
  return value.toString();
}

class VendorIdentityVerification {
  final String? id;
  final String vendorId;
  final String? verificationProvider;
  final String? providerReference;
  final String? verificationMethod;
  final String status;
  final DateTime? consentRecordedAt;
  final DateTime? submittedAt;
  final DateTime? verifiedAt;
  final String? failureReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const VendorIdentityVerification({
    this.id,
    required this.vendorId,
    this.verificationProvider,
    this.providerReference,
    this.verificationMethod,
    this.status = 'not_started',
    this.consentRecordedAt,
    this.submittedAt,
    this.verifiedAt,
    this.failureReason,
    this.createdAt,
    this.updatedAt,
  });

  factory VendorIdentityVerification.fromMap(
    Map<String, dynamic> map,
  ) {
    return VendorIdentityVerification(
      id: _stringFrom(map['id']),
      vendorId: map['vendor_id'].toString(),
      verificationProvider: _stringFrom(map['verification_provider']),
      providerReference: _stringFrom(map['provider_reference']),
      verificationMethod: _stringFrom(map['verification_method']),
      status: map['status']?.toString() ?? 'not_started',
      consentRecordedAt: _dateFrom(map['consent_recorded_at']),
      submittedAt: _dateFrom(map['submitted_at']),
      verifiedAt: _dateFrom(map['verified_at']),
      failureReason: _stringFrom(map['failure_reason']),
      createdAt: _dateFrom(map['created_at']),
      updatedAt: _dateFrom(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vendor_id': vendorId,
      'verification_provider': verificationProvider,
      'provider_reference': providerReference,
      'verification_method': verificationMethod,
      'status': status,
      'consent_recorded_at': consentRecordedAt?.toUtc().toIso8601String(),
      'submitted_at': submittedAt?.toUtc().toIso8601String(),
      'verified_at': verifiedAt?.toUtc().toIso8601String(),
      'failure_reason': failureReason,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

class VendorVerification {
  final String? id;
  final String vendorId;
  final String status;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? reviewNote;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const VendorVerification({
    this.id,
    required this.vendorId,
    this.status = 'not_started',
    this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewNote,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  factory VendorVerification.fromMap(Map<String, dynamic> map) {
    return VendorVerification(
      id: _stringFrom(map['id']),
      vendorId: map['vendor_id'].toString(),
      status: map['status']?.toString() ?? 'not_started',
      submittedAt: _dateFrom(map['submitted_at']),
      reviewedAt: _dateFrom(map['reviewed_at']),
      reviewedBy: _stringFrom(map['reviewed_by']),
      reviewNote: _stringFrom(map['review_note']),
      rejectionReason: _stringFrom(map['rejection_reason']),
      createdAt: _dateFrom(map['created_at']),
      updatedAt: _dateFrom(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vendor_id': vendorId,
      'status': status,
      'submitted_at': submittedAt?.toUtc().toIso8601String(),
      'reviewed_at': reviewedAt?.toUtc().toIso8601String(),
      'reviewed_by': reviewedBy,
      'review_note': reviewNote,
      'rejection_reason': rejectionReason,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

class VerificationDocument {
  final String? id;
  final String vendorId;
  final String? businessId;
  final String documentType;
  final String? storagePath;
  final String status;
  final String? originalFilename;
  final String? mimeType;
  final int? fileSizeBytes;
  final int submissionVersion;
  final DateTime? uploadedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const VerificationDocument({
    this.id,
    required this.vendorId,
    this.businessId,
    required this.documentType,
    this.storagePath,
    this.status = 'selected',
    this.originalFilename,
    this.mimeType,
    this.fileSizeBytes,
    this.submissionVersion = 1,
    this.uploadedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
  });

  factory VerificationDocument.fromMap(Map<String, dynamic> map) {
    return VerificationDocument(
      id: _stringFrom(map['id']),
      vendorId: map['vendor_id'].toString(),
      businessId: _stringFrom(map['business_id']),
      documentType: map['document_type']?.toString() ?? '',
      storagePath: _stringFrom(map['storage_path']),
      status: map['status']?.toString() ?? 'selected',
      originalFilename: _stringFrom(map['original_filename']),
      mimeType: _stringFrom(map['mime_type']),
      fileSizeBytes: map['file_size_bytes'] == null
          ? null
          : int.tryParse(map['file_size_bytes'].toString()),
      submissionVersion:
          int.tryParse(map['submission_version'].toString()) ?? 1,
      uploadedAt: _dateFrom(map['uploaded_at']),
      reviewedAt: _dateFrom(map['reviewed_at']),
      reviewedBy: _stringFrom(map['reviewed_by']),
      rejectionReason: _stringFrom(map['rejection_reason']),
      createdAt: _dateFrom(map['created_at']),
      updatedAt: _dateFrom(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vendor_id': vendorId,
      'business_id': businessId,
      'document_type': documentType,
      'storage_path': storagePath,
      'status': status,
      'original_filename': originalFilename,
      'mime_type': mimeType,
      'file_size_bytes': fileSizeBytes,
      'submission_version': submissionVersion,
      'uploaded_at': uploadedAt?.toUtc().toIso8601String(),
      'reviewed_at': reviewedAt?.toUtc().toIso8601String(),
      'reviewed_by': reviewedBy,
      'rejection_reason': rejectionReason,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
