import 'package:eventor_admin/screens/extended/admin_session_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const session = <String, dynamic>{
    'id': 'staff',
    'access_level': 'staff',
    'mfa_required': false,
    'permissions': {'banners': true, 'services': false},
  };

  test('A file chooser resume with identical access keeps the editor open', () {
    expect(
      adminAccessChanged(session, {
        ...session,
        'permissions': {'services': false, 'banners': true},
      }),
      isFalse,
    );
  });

  test('Access removal, permission changes and stronger MFA close protected routes', () {
    expect(adminAccessChanged(session, null), isTrue);
    expect(
      adminAccessChanged(session, {
        ...session,
        'permissions': {'banners': false, 'services': false},
      }),
      isTrue,
    );
    expect(
      adminAccessChanged(session, {
        ...session,
        'access_level': 'admin',
        'mfa_required': true,
      }),
      isTrue,
    );
  });
}
