import 'package:flutter/material.dart';

import '../models/app_settings_model.dart';
import '../repositories/app_settings_repository.dart';
import 'notification_service.dart';

class AppSettingsController extends ChangeNotifier {
  AppSettingsController({
    required AppSettingsModel initial,
    AppSettingsRepository? repository,
    Future<bool> Function()? enableNotifications,
    Future<void> Function()? disableNotifications,
    Future<bool?> Function()? notificationPermission,
  }) : _value = initial.copyWith(themeMode: ThemeMode.light),
       _repository = repository ?? AppSettingsRepository(),
       _enable = enableNotifications,
       _disable = disableNotifications,
       _permission = notificationPermission;
  final AppSettingsRepository _repository;
  final Future<bool> Function()? _enable;
  final Future<void> Function()? _disable;
  final Future<bool?> Function()? _permission;
  AppSettingsModel _value;
  AppSettingsModel get value => _value;
  bool _busy = false;
  bool get busy => _busy;
  bool get tamil => _value.languageCode == 'ta';
  String text(String english, String tamilText) => tamil ? tamilText : english;
  Future<void> disablePush() =>
      _disable?.call() ??
      NotificationService.instance.removeToken(reportFailure: true);
  Future<String?> setNotifications(bool enabled) async {
    if (_busy) {
      return null;
    }
    _busy = true;
    notifyListeners();
    try {
      await _repository.saveNotifications(enabled);
      _value = _value.copyWith(notificationsEnabled: enabled);
      notifyListeners();
      if (!enabled) {
        try {
          await disablePush();
        } catch (_) {
          return text(
            'Notifications are off in Eventor. Device registration cleanup could not be confirmed; retry when connected.',
            'Eventor அறிவிப்புகள் அணைக்கப்பட்டன. சாதனப் பதிவு நீக்கத்தை உறுதிப்படுத்த முடியவில்லை; இணைப்பு கிடைத்ததும் மீண்டும் முயற்சிக்கவும்.',
          );
        }
        return null;
      }
      bool allowed;
      try {
        allowed =
            await (_enable?.call() ??
                NotificationService.instance.initialize());
      } catch (_) {
        allowed = false;
      }
      if (!allowed) {
        await _repository.saveNotifications(false);
        _value = _value.copyWith(notificationsEnabled: false);
        notifyListeners();
        try {
          await disablePush();
        } catch (_) {
          /* OFF remains persisted. */
        }
        return text(
          'Notifications are blocked or unavailable. Check Phone Settings and try again.',
          'அறிவிப்புகள் தடுக்கப்பட்டுள்ளன அல்லது கிடைக்கவில்லை. தொலைபேசி அமைப்புகளைச் சரிபார்த்து மீண்டும் முயற்சிக்கவும்.',
        );
      }
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> syncNotificationPermission() async {
    if (_busy || !_value.notificationsEnabled) {
      return;
    }
    try {
      final allowed =
          await (_permission?.call() ??
              NotificationService.instance.permissionAllowed());
      if (allowed == false && !_busy && _value.notificationsEnabled) {
        await setNotifications(false);
      }
    } catch (_) {
      /* Keep the last saved choice when the OS status cannot be read. */
    }
  }

  Future<void> setLanguage(String code) async {
    if (_busy) {
      return;
    }
    _busy = true;
    notifyListeners();
    try {
      await _repository.saveLanguage(code);
      _value = _value.copyWith(languageCode: code);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  // Kept for compatibility with older callers. The app is always light now.
  Future<void> setTheme(ThemeMode mode) async {
    await _repository.saveTheme(ThemeMode.light);
    _value = _value.copyWith(themeMode: ThemeMode.light);
    notifyListeners();
  }
}

class AppSettingsScope extends InheritedNotifier<AppSettingsController> {
  const AppSettingsScope({
    super.key,
    required AppSettingsController controller,
    required super.child,
  }) : super(notifier: controller);
  static AppSettingsController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'Wrap MaterialApp with AppSettingsScope.');
    return scope!.notifier!;
  }
}
