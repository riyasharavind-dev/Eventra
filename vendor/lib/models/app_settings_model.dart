import 'package:flutter/material.dart';

class AppSettingsModel {
  const AppSettingsModel({
    this.notificationsEnabled = true,
    this.languageCode = 'en',
    this.themeMode = ThemeMode.light,
  });

  final bool notificationsEnabled;
  final String languageCode;
  final ThemeMode themeMode;

  AppSettingsModel copyWith({
    bool? notificationsEnabled,
    String? languageCode,
    ThemeMode? themeMode,
  }) {
    return AppSettingsModel(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      languageCode: languageCode ?? this.languageCode,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}
