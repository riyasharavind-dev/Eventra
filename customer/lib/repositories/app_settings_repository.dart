import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings_model.dart';

class AppSettingsRepository {
  static const _notifications = 'eventor.customer.notifications';
  static const _language = 'eventor.customer.language';
  static const _appearance = 'eventor.customer.appearance';

  Future<AppSettingsModel> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettingsModel(
      notificationsEnabled: prefs.getBool(_notifications) ?? true,
      languageCode: prefs.getString(_language) == 'ta' ? 'ta' : 'en',
      themeMode: ThemeMode.light,
    );
  }

  Future<void> saveNotifications(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(_notifications, enabled)) {
      throw Exception('Could not save notification preference.');
    }
  }

  Future<void> saveLanguage(String code) async {
    if (code != 'en' && code != 'ta') {
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
