import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_vendor/models/app_account_identity.dart';

void main() {
  test('contact fields are not treated as a verified phone', () {
    final identity = AppAccountIdentity.fromMap({
      'user_id': 'existing-uid',
      'account_role': 'vendor',
      'phone': '+919999990001',
    });
    expect(identity.verifiedPhone, isNull);
    expect(identity.userId, 'existing-uid');
  });
  test(
    'verified number requires both a canonical phone and verification time',
    () {
      for (final fields in [
        {'verified_phone': '+919999990001'},
        {'phone_verified_at': '2026-11-08T10:00:00Z'},
        {
          'verified_phone': '9999990001',
          'phone_verified_at': '2026-11-08T10:00:00Z',
        },
      ]) {
        expect(
          () => AppAccountIdentity.fromMap({
            'user_id': 'existing-uid',
            'account_role': 'vendor',
            ...fields,
          }),
          throwsFormatException,
        );
      }
    },
  );
  test('verified mapping retains the original account identity', () {
    final identity = AppAccountIdentity.fromMap({
      'user_id': 'existing-uid',
      'account_role': 'vendor',
      'verified_phone': '+919999990001',
      'phone_verified_at': '2026-11-08T10:00:00Z',
    });
    expect(identity.userId, 'existing-uid');
    expect(identity.accountRole, 'vendor');
    expect(identity.verifiedPhone, '+919999990001');
    expect(identity.phoneVerifiedAt, isNotNull);
  });
  test('admin and unknown identities cannot become an app account', () {
    expect(
      () => AppAccountIdentity.fromMap({
        'user_id': 'uid',
        'account_role': 'admin',
      }),
      throwsFormatException,
    );
  });
}
