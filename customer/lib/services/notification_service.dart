import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance =
      NotificationService._();

  final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  final SupabaseClient _supabase =
      Supabase.instance.client;

  bool _initialized = false;

  // ============================================================
  // INITIALIZE FCM
  // ============================================================

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    final user = _supabase.auth.currentUser;

    if (user == null) {
      debugPrint(
        'NotificationService: No logged-in user.',
      );
      return;
    }

    try {
      // --------------------------------------------------------
      // 1. Request notification permission
      // --------------------------------------------------------

      final settings =
          await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus ==
          AuthorizationStatus.denied) {
        debugPrint(
          'NotificationService: Permission denied.',
        );
        return;
      }

      // --------------------------------------------------------
      // 2. Get FCM token
      // --------------------------------------------------------

      String? token;

      if (Platform.isAndroid || Platform.isIOS) {
        token = await _messaging.getToken();
      }

      if (token == null || token.isEmpty) {
        debugPrint(
          'NotificationService: FCM token unavailable.',
        );
        return;
      }

      debugPrint(
        'NotificationService: FCM token received.',
      );

      // --------------------------------------------------------
      // 3. Save token
      // --------------------------------------------------------

      await _saveToken(
        userId: user.id,
        token: token,
      );

      // --------------------------------------------------------
      // 4. Listen for token refresh
      // --------------------------------------------------------

      _messaging.onTokenRefresh.listen(
        (newToken) async {
          final currentUser =
              _supabase.auth.currentUser;

          if (currentUser == null) {
            return;
          }

          debugPrint(
            'NotificationService: FCM token refreshed.',
          );

          await _saveToken(
            userId: currentUser.id,
            token: newToken,
          );
        },
        onError: (error) {
          debugPrint(
            'NotificationService: '
            'Token refresh error: $error',
          );
        },
      );

      // --------------------------------------------------------
      // 5. Foreground notification listener
      // --------------------------------------------------------

      FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) {
          final title =
              message.notification?.title;

          final body =
              message.notification?.body;

          debugPrint(
            'NotificationService: '
            'Foreground notification received.',
          );

          debugPrint(
            'Notification title: $title',
          );

          debugPrint(
            'Notification body: $body',
          );

          debugPrint(
            'Notification data: ${message.data}',
          );
        },
        onError: (error) {
          debugPrint(
            'NotificationService: '
            'Foreground message error: $error',
          );
        },
      );

      _initialized = true;

      debugPrint(
        'NotificationService: '
        'Initialized successfully.',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'NotificationService: '
        'Initialization failed: $e',
      );

      debugPrint(
        'NotificationService stack trace: '
        '$stackTrace',
      );
    }
  }

  // ============================================================
  // SAVE FCM TOKEN
  // ============================================================

  Future<void> _saveToken({
    required String userId,
    required String token,
  }) async {
    try {
      final String platform;

      if (Platform.isAndroid) {
        platform = 'android';
      } else if (Platform.isIOS) {
        platform = 'ios';
      } else {
        platform = 'other';
      }

      await _supabase.from('fcm_tokens').upsert(
        {
          'user_id': userId,
          'token': token,
          'platform': platform,
          'updated_at':
              DateTime.now().toIso8601String(),
        },
        onConflict: 'token',
      );

      debugPrint(
        'NotificationService: '
        'FCM token saved successfully.',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'NotificationService: '
        'Failed to save FCM token: $e',
      );

      debugPrint(
        'NotificationService stack trace: '
        '$stackTrace',
      );
    }
  }

  // ============================================================
  // REMOVE FCM TOKEN
  // ============================================================

  Future<void> removeToken() async {
    try {
      final token =
          await _messaging.getToken();

      if (token == null || token.isEmpty) {
        return;
      }

      await _supabase
          .from('fcm_tokens')
          .delete()
          .eq('token', token);

      debugPrint(
        'NotificationService: '
        'FCM token removed successfully.',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'NotificationService: '
        'Failed to remove FCM token: $e',
      );

      debugPrint(
        'NotificationService stack trace: '
        '$stackTrace',
      );
    }
  }
}