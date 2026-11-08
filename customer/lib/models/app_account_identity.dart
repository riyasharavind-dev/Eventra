/// A server-validated app identity. Contact phone fields are deliberately absent.
class AppAccountIdentity {
  const AppAccountIdentity({
    required this.userId,
    required this.accountRole,
    this.verifiedPhone,
    this.phoneVerifiedAt,
  });
  final String userId;
  final String accountRole;
  final String? verifiedPhone;
  final DateTime? phoneVerifiedAt;

  factory AppAccountIdentity.fromMap(Map<String, dynamic> map) {
    final phone = map['verified_phone'] as String?;
    final verifiedAt = DateTime.tryParse(
      map['phone_verified_at']?.toString() ?? '',
    );
    final role = map['account_role'];
    final id = map['user_id'];
    if (id is! String ||
        id.isEmpty ||
        (role != 'customer' && role != 'vendor') ||
        ((phone == null) != (verifiedAt == null)) ||
        (phone != null && !RegExp(r'^\+[1-9][0-9]{6,14}$').hasMatch(phone))) {
      throw const FormatException('Invalid app account identity');
    }
    return AppAccountIdentity(
      userId: id,
      accountRole: role as String,
      verifiedPhone: phone,
      phoneVerifiedAt: verifiedAt,
    );
  }
}
