import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings_model.dart';

class AppSettingsRepository {
  static const _notifications = 'eventor.vendor.notifications';
  static const _language = 'eventor.vendor.language';
  static const _appearance = 'eventor.vendor.appearance';

  Future<AppSettingsModel> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedLanguage = prefs.getString(_language) ?? 'en';
    final language =
        RegExp(r'^[a-z]{2,3}(-[A-Za-z0-9]{2,8}){0,2}$').hasMatch(storedLanguage)
        ? storedLanguage
        : 'en';
    return AppSettingsModel(
      notificationsEnabled: prefs.getBool(_notifications) ?? true,
      languageCode: language,
      themeMode: ThemeMode.light,
    );
  }

  Future<void> saveNotifications(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(_notifications, enabled)) {
      throw Exception('Could not save notification preference.');
    }
  }

  /// A stored valid choice includes English; the implicit default is not a choice.
  Future<bool> hasSelectedLanguage() async {
    final value = (await SharedPreferences.getInstance()).getString(_language);
    return value != null &&
        RegExp(r'^[a-z]{2,3}(-[A-Za-z0-9]{2,8}){0,2}$').hasMatch(value);
  }

  Future<void> saveLanguage(String code) async {
    if (!RegExp(r'^[a-z]{2,3}(-[A-Za-z0-9]{2,8}){0,2}$').hasMatch(code)) {
      throw ArgumentError('Unsupported language');
    }
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_language, code)) {
      throw Exception('Could not save language preference.');
    }
  }

  Future<void> saveTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_appearance, ThemeMode.light.name)) {
      throw Exception('Could not save appearance preference.');
    }
  }
}
