import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vendor/utils/auth_error_message.dart';

void main() {
  test(
    'invalid credentials have a readable message without server details',
    () {
      expect(
        authErrorMessage(
          const AuthException(
            'sensitive server detail',
            code: 'invalid_credentials',
          ),
        ),
        'Email or password is incorrect.',
      );
    },
  );
  test('unknown auth and database errors never expose internals', () {
    for (final error in [
      const AuthException('private server details'),
      const PostgrestException(message: 'private database detail'),
      Exception('private'),
    ]) {
      expect(
        authErrorMessage(error),
        'Unable to complete this action. Please try again.',
      );
    }
  });
  test('verification, rate limit and role mismatch have clear messages', () {
    expect(
      authErrorMessage(const AuthException('raw', code: 'email_not_confirmed')),
      contains('verify your email'),
    );
    expect(
      authErrorMessage(
        const AuthException('raw', code: 'over_request_rate_limit'),
      ),
      contains('Too many attempts'),
    );
    expect(
      authErrorMessage(
        const AccountAccessException('Please use a vendor account.'),
      ),
      'Please use a vendor account.',
    );
  });
}
