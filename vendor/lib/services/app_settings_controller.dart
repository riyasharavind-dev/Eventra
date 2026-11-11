import 'vendor_localization.dart';

import 'package:flutter/material.dart';

import '../models/app_settings_model.dart';
import '../repositories/app_settings_repository.dart';
import 'notification_service.dart';

class AppSettingsController extends ChangeNotifier {
  AppSettingsController({
    required AppSettingsModel initial,
    AppSettingsRepository? repository,
    VendorLocalization? localization,
    Future<bool> Function()? enableNotifications,
    Future<void> Function()? disableNotifications,
    Future<bool?> Function()? notificationPermission,
  }) : _value = initial.copyWith(themeMode: ThemeMode.light),
       _repository = repository ?? AppSettingsRepository(),
       _enable = enableNotifications,
       _disable = disableNotifications,
       _permission = notificationPermission,
       localization =
           localization ?? VendorLocalization(code: initial.languageCode) {
    this.localization.addListener(_languageChanged);
  }
  final VendorLocalization localization;
  void _languageChanged() => notifyListeners();
  String tr(String key, {Map<String, Object?> args = const {}}) =>
      localization.tr(key, args: args);
  String get languageName => localization.selected.nativeName;
  @override
  void dispose() {
    localization.removeListener(_languageChanged);
    localization.dispose();
    super.dispose();
  }

  final AppSettingsRepository _repository;
  final Future<bool> Function()? _enable;
  final Future<void> Function()? _disable;
  final Future<bool?> Function()? _permission;
  AppSettingsModel _value;
  AppSettingsModel get value => _value;
  bool _busy = false;
  bool get busy => _busy;
  String text(String english) => localization.source(english);
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
          return tr(
            "vendor.notifications_are_off_in_eventor_device_regis.9506c661",
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
        return tr(
          "vendor.notifications_are_blocked_or_unavailable_chec.0e26d341",
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
      final pack = await localization.prepare(code);
      await _repository.saveLanguage(code);
      _value = _value.copyWith(languageCode: code);
      localization.activate(code, pack);
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
  static final _englishFallback = VendorLocalization(code: 'en');
  static VendorLocalization localizationOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppSettingsScope>()
          ?.notifier
          ?.localization ??
      _englishFallback;
  static String translate(
    BuildContext context,
    String key, {
    Map<String, Object?> args = const {},
  }) => localizationOf(context).tr(key, args: args);
  static String source(BuildContext context, String english) =>
      localizationOf(context).source(english);
  static AppSettingsController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'Wrap MaterialApp with AppSettingsScope.');
    return scope!.notifier!;
  }
}
