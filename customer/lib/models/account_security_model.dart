class AccountDeletionRequest {
  const AccountDeletionRequest({
    required this.id,
    required this.status,
    required this.requestedAt,
    this.publicNote,
  });
  final String id;
  final String status;
  final DateTime requestedAt;
  final String? publicNote;
  bool get active => status == 'pending' || status == 'in_review';
  String get label => switch (status) {
    'pending' => 'Pending review',
    'in_review' => 'Under review',
    'completed' => 'Completed',
    'rejected' => 'Not approved',
    'cancelled' => 'Cancelled',
    _ => status,
  };
  factory AccountDeletionRequest.fromMap(Map<String, dynamic> map) =>
      AccountDeletionRequest(
        id: map['id'] as String,
        status: map['status'] as String,
        requestedAt: DateTime.parse(map['requested_at'] as String),
        publicNote: map['public_note'] as String?,
      );
}

class AccountSecurityModel {
  const AccountSecurityModel({
    required this.email,
    this.pendingEmail,
    this.phone,
    this.deletionRequest,
  });
  final String email;
  final String? pendingEmail;
  final String? phone;
  final AccountDeletionRequest? deletionRequest;
  factory AccountSecurityModel.fromMap(Map<String, dynamic> map) =>
      AccountSecurityModel(
        email: map['email'] as String,
        pendingEmail: map['pending_email'] as String?,
        phone: map['phone'] as String?,
        deletionRequest: map['deletion_request'] == null
            ? null
            : AccountDeletionRequest.fromMap(
                Map<String, dynamic>.from(map['deletion_request'] as Map),
              ),
      );
}
