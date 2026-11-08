import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class AccountAccessException implements Exception {
  const AccountAccessException(this.message);
  final String message;
}

String authErrorMessage(Object error) {
  if (error is AccountAccessException) return error.message;
  if (error is SocketException ||
      error is TimeoutException ||
      error is AuthRetryableFetchException) {
    return 'Check your internet connection and try again.';
  }
  if (error is AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
        return 'Email or password is incorrect.';
      case 'user_not_found':
        return 'No account found with this email.';
      case 'email_not_confirmed':
        return 'Please verify your email before signing in.';
      case 'user_already_exists':
      case 'email_exists':
        return 'An account with this email already exists. Please sign in.';
      case 'weak_password':
        return 'Please choose a stronger password.';
      case 'same_password':
        return 'Choose a different password from your current password.';
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'session_expired':
      case 'refresh_token_not_found':
        return 'Your session has expired. Please sign in again.';
      case 'signup_disabled':
        return 'Account registration is currently unavailable. Please try later.';
      case 'email_address_invalid':
        return 'Please enter a valid email address.';
    }
  }
  return 'Unable to complete this action. Please try again.';
}
