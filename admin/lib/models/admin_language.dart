class AdminLanguage {
  const AdminLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.direction,
    required this.enabled,
    required this.version,
    required this.revision,
    required this.total,
    required this.translated,
    this.fallbacks = 0,
  });
  final String code, name, nativeName, direction;
  final bool enabled;
  final int version, revision, total, translated, fallbacks;
  factory AdminLanguage.fromMap(Map<String, dynamic> m) => AdminLanguage(
    code: m['code'] as String,
    name: m['name'] as String,
    nativeName: m['native_name'] as String,
    direction: m['direction'] as String,
    enabled: m['is_enabled'] == true,
    version: (m['published_version'] as num).toInt(),
    revision: (m['draft_revision'] as num).toInt(),
    total: (m['total'] as num).toInt(),
    translated: (m['translated'] as num).toInt(),
    fallbacks: (m['published_fallbacks'] as num?)?.toInt() ?? 0,
  );
}

class TranslationEntry {
  const TranslationEntry({
    required this.key,
    required this.source,
    required this.value,
    required this.module,
    required this.notes,
    required this.placeholders,
    required this.invalid,
  });
  final String key, source, value, module, notes;
  final List<String> placeholders;
  final bool invalid;
  factory TranslationEntry.fromMap(Map<String, dynamic> m) => TranslationEntry(
    key: m['key'] as String,
    source: m['default_text'] as String,
    value: m['translation'] as String,
    module: m['module'] as String,
    notes: m['notes'] as String,
    placeholders: List<String>.from(m['placeholders'] as List),
    invalid: m['invalid'] == true,
  );
}
