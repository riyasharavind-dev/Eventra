import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../l10n/vendor_strings.dart';

class AppLanguageOption {
  const AppLanguageOption({
    required this.code,
    required this.name,
    required this.nativeName,
    this.direction = 'ltr',
    this.version = 0,
    this.checksum = '',
  });
  final String code, name, nativeName, direction, checksum;
  final int version;
  static const english = AppLanguageOption(
    code: 'en',
    name: 'English',
    nativeName: 'English',
  );
  factory AppLanguageOption.fromMap(Map<String, dynamic> map) {
    final code = map['code'] as String;
    if (!RegExp(r'^[a-z]{2,3}(-[A-Za-z0-9]{2,8}){0,2}$').hasMatch(code)) {
      throw const FormatException('Invalid language code');
    }
    final direction = map['direction'] as String? ?? 'ltr';
    if (!['ltr', 'rtl'].contains(direction)) {
      throw const FormatException('Invalid direction');
    }
    return AppLanguageOption(
      code: code,
      name: map['name'] as String,
      nativeName: map['native_name'] as String,
      direction: direction,
      version: (map['version'] as num?)?.toInt() ?? 0,
      checksum: map['sha256'] as String? ?? '',
    );
  }
  Map<String, dynamic> toMap() => {
    'code': code,
    'name': name,
    'native_name': nativeName,
    'direction': direction,
    'version': version,
    'sha256': checksum,
  };
}

Set<String> messagePlaceholders(String text) =>
    RegExp(r'\{([A-Za-z][A-Za-z0-9_]*)\}')
        .allMatches(text)
        .map((m) => m[1]!)
        .toSet();

class AppLanguagePack {
  const AppLanguagePack({
    required this.option,
    required this.messages,
    required this.content,
    required this.checksum,
    required this.direction,
  });
  final AppLanguageOption option;
  final Map<String, String> messages;
  final String content, checksum, direction;
  factory AppLanguagePack.parse(
    Map<String, dynamic> envelope,
    AppLanguageOption option,
  ) {
    final content = envelope['content'] as String;
    final bytes = utf8.encode(content);
    if (bytes.length > 2097152) {
      throw const FormatException('Language pack too large');
    }
    final digest = sha256.convert(bytes).toString();
    if (digest != envelope['sha256'] ||
        (option.checksum.isNotEmpty && digest != option.checksum)) {
      throw const FormatException('Language checksum mismatch');
    }
    final json = jsonDecode(content) as Map<String, dynamic>;
    if (json['schema'] != 1 ||
        json['app'] != 'vendor' ||
        json['code'] != option.code ||
        json['version'] != option.version ||
        !['ltr', 'rtl'].contains(json['direction'])) {
      throw const FormatException('Invalid language pack');
    }
    final data = json['messages'];
    if (data is! Map || data.isEmpty || data.length > 5000) {
      throw const FormatException('Invalid translations');
    }
    final messages = <String, String>{};
    for (final entry in data.entries) {
      if (entry.key is! String ||
          entry.value is! String ||
          (entry.value as String).length > 12000) {
        throw const FormatException('Invalid translation value');
      }
      final key = entry.key as String,
          value = entry.value as String,
          source = vendorEnglishStrings[key];
      if (source != null) {
        final expected = messagePlaceholders(source),
            actual = messagePlaceholders(value);
        if (expected.length != actual.length || !expected.containsAll(actual)) {
          throw const FormatException('Invalid translation placeholders');
        }
      }
      messages[key] = value;
    }
    return AppLanguagePack(
      option: option,
      messages: Map.unmodifiable(messages),
      content: content,
      checksum: digest,
      direction: json['direction'] as String,
    );
  }
  Map<String, dynamic> toCache() => {
    'option': option.toMap(),
    'content': content,
    'sha256': checksum,
  };
}
