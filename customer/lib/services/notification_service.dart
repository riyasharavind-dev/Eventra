import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/app_settings_repository.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();
  final _supabase = Supabase.instance.client;
  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _foreground;
  Future<bool>? _inFlight;
  String? _initializedUser;
  bool _enabled = false;
  int _generation = 0;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<bool> initialize() {
    if (_inFlight != null) return _inFlight!;
    final operation = _initialize();
    _inFlight = operation;
    return operation.whenComplete(() {
      if (identical(_inFlight, operation)) _inFlight = null;
    });
  }

  Future<bool> _initialize() async {
    final generation = _generation;
    if (!_supported) return false;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    final prefs = await AppSettingsRepository().load();
    if (generation != _generation) return false;
    if (!prefs.notificationsEnabled) {
      await FirebaseMessaging.instance.setAutoInitEnabled(false);
      await FirebaseMessaging.instance.deleteToken();
      return false;
    }
    if (_initializedUser == userId && _enabled) return true;
    final messaging = FirebaseMessaging.instance;
    final permission = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (permission.authorizationStatus != AuthorizationStatus.authorized &&
        permission.authorizationStatus != AuthorizationStatus.provisional) {
      return false;
    }
    if (generation != _generation || _supabase.auth.currentUser?.id != userId) {
      return false;
    }
    await messaging.setAutoInitEnabled(true);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    final token = await messaging.getToken();
    if (generation != _generation || _supabase.auth.currentUser?.id != userId) {
      return false;
    }
    if (token == null || token.isEmpty) {
      throw Exception('Notification registration unavailable.');
    }
    await _saveToken(token, userId);
    if (generation != _generation || _supabase.auth.currentUser?.id != userId) {
      await _supabase
          .from('fcm_tokens')
          .delete()
          .eq('user_id', userId)
          .eq('token', token);
      return false;
    }
    await _tokenRefresh?.cancel();
    await _foreground?.cancel();
    _enabled = true;
    _initializedUser = userId;
    _tokenRefresh = messaging.onTokenRefresh.listen((token) async {
      if (!_enabled || _supabase.auth.currentUser?.id != userId) return;
      try {
        final prefs = await AppSettingsRepository().load();
        if (_enabled && prefs.notificationsEnabled) {
          await _saveToken(token, userId);
        }
      } catch (error) {
        debugPrint('Notification registration refresh failed: $error');
      }
    });
    _foreground = FirebaseMessaging.onMessage.listen((message) {
      if (_enabled) debugPrint('Eventra customer notification received.');
    });
    return true;
  }

  Future<void> _saveToken(String token, String userId) async {
    if (_supabase.auth.currentUser?.id != userId) return;
    await _supabase.from('fcm_tokens').upsert({
      'user_id': userId,
      'token': token,
      'platform': defaultTargetPlatform == TargetPlatform.android
          ? 'android'
          : 'ios',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'token');
  }

  Future<void> removeToken({bool reportFailure = false}) async {
    _generation++;
    _enabled = false;
    _initializedUser = null;
    await _tokenRefresh?.cancel();
    await _foreground?.cancel();
    _tokenRefresh = null;
    _foreground = null;
    if (!_supported) return;
    // Finish any older registration before disabling SDK auto-init and deleting
    // the token; otherwise a late registration can turn auto-init back on.
    final pending = _inFlight;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {
        /* Cleanup still runs. */
      }
    }
    final messaging = FirebaseMessaging.instance;
    final userId = _supabase.auth.currentUser?.id;
    Object? failure;
    try {
      await messaging.setAutoInitEnabled(false);
    } catch (error) {
      failure = error;
    }
    try {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
    } catch (error) {
      failure = error;
    }
    try {
      final token = await messaging.getToken();
      if (token != null && userId != null) {
        await _supabase
            .from('fcm_tokens')
            .delete()
            .eq('user_id', userId)
            .eq('token', token);
      }
    } catch (error) {
      failure = error;
    }
    // Revoke this installation's token even if the database delete failed.
    try {
      await messaging.deleteToken();
    } catch (error) {
      failure = error;
    }
    if (failure != null) {
      if (reportFailure) {
        throw Exception(
          'Could not confirm notification cleanup. Please retry.',
        );
      }
      debugPrint('Notification cleanup could not be confirmed.');
    }
  }

  Future<bool?> permissionAllowed() async {
    if (!_supported) return null;
    final status = await FirebaseMessaging.instance.getNotificationSettings();
    if (status.authorizationStatus == AuthorizationStatus.notDetermined) {
      return null;
    }
    return status.authorizationStatus == AuthorizationStatus.authorized ||
        status.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> dispose() async {
    _generation++;
    _enabled = false;
    _initializedUser = null;
    await _tokenRefresh?.cancel();
    await _foreground?.cancel();
    _tokenRefresh = null;
    _foreground = null;
  }
}
