import 'package:flutter/material.dart';

class SettingsSearchItem {
  final String id, title, subtitle;
  final List<String> keywords;
  final IconData icon;
  final VoidCallback onTap;
  const SettingsSearchItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.keywords = const [],
  });

  bool matches(String query) {
    final words = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    final text = '$title $subtitle ${keywords.join(' ')}'.toLowerCase();
    return words.every(text.contains);
  }
}
