import 'dart:convert';

String adminLabel(String key) =>
    const <String, String>{
      'all': 'Both apps',
      'audience': 'App audience',
      'waiting_for_vendor': 'Awaiting requester reply',
    }[key] ??
    key
        .split('_')
        .map((s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}')
        .join(' ');

class AdminField {
  final String name, type;
  final bool required, nullable, writable;
  final String? defaultSql, referenceTable, referenceColumn;
  final List<String> choices;
  const AdminField({
    required this.name,
    required this.type,
    this.required = false,
    this.nullable = true,
    this.writable = false,
    this.defaultSql,
    this.referenceTable,
    this.referenceColumn,
    this.choices = const [],
  });
  factory AdminField.fromMap(Map<String, dynamic> m) => AdminField(
    name: m['name'] as String,
    type: m['type'] as String,
    required: m['required'] == true,
    nullable: m['nullable'] == true,
    writable: m['writable'] == true,
    defaultSql: m['default'] as String?,
    referenceTable: m['reference_table'] as String?,
    referenceColumn: m['reference_column'] as String?,
    choices: List<String>.from(m['choices'] as List? ?? []),
  );
  String get label => adminLabel(name);
  bool get numeric =>
      ['int2', 'int4', 'int8', 'numeric', 'float4', 'float8'].contains(type);
  bool get image =>
      name.endsWith('image_url') ||
      name.endsWith('logo_url') ||
      name == 'banner_url' ||
      name == 'avatar_url' ||
      name == 'icon_url';
  bool get longText => [
    'description',
    'introduction',
    'content_markdown',
    'answer',
    'body',
    'review_text',
    'review_note',
    'public_note',
    'about_me',
    'requirement',
    'moderation_note',
    'admin_note',
    'failure_reason',
    'rejection_reason',
    'reason',
    'note',
  ].contains(name);
  dynamic defaultValue() {
    if (type == 'bool') {
      return defaultSql?.contains('true') ?? false;
    }
    if (type == 'jsonb' || type.startsWith('_')) {
      return <dynamic>[];
    }
    if (defaultSql != null && numeric) {
      return num.tryParse(defaultSql!.split('::').first);
    }
    if (defaultSql?.startsWith("'") == true) {
      return defaultSql!.split("'")[1];
    }
    if (name == 'language_code') {
      return 'en';
    }
    return null;
  }

  dynamic parse(String text) {
    final v = text.trim();
    if (v.isEmpty) {
      return nullable ? null : '';
    }
    if (numeric) {
      final value = num.tryParse(v);
      if (value == null || !value.isFinite) {
        throw FormatException('Enter a valid $label');
      }
      if (type.startsWith('int') && value != value.roundToDouble()) {
        throw FormatException('$label must be a whole number');
      }
      return value;
    }
    if (type.startsWith('_')) {
      return v
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (type == 'jsonb') {
      return jsonDecode(v);
    }
    if (type == 'timestamptz') {
      final date = DateTime.tryParse(v);
      if (date == null) {
        throw FormatException('Enter a valid $label');
      }
      return date.toUtc().toIso8601String();
    }
    if (type == 'date' && DateTime.tryParse(v) == null) {
      throw FormatException('Enter date as YYYY-MM-DD');
    }
    return v;
  }
}

class AdminModule {
  final String name, label, section, pk;
  final bool canCreate;
  final List<AdminField> fields;
  final List<String> actions;
  const AdminModule({
    required this.name,
    required this.label,
    required this.section,
    this.pk = 'id',
    this.canCreate = false,
    this.fields = const [],
    this.actions = const [],
  });
  factory AdminModule.fromMap(Map<String, dynamic> m) => AdminModule(
    name: m['name'] as String,
    label: m['label'] as String,
    section: m['section'] as String,
    pk: m['pk'] as String,
    canCreate: m['can_create'] == true,
    fields: (m['fields'] as List? ?? [])
        .map((f) => AdminField.fromMap(Map<String, dynamic>.from(f as Map)))
        .toList(),
    actions: List<String>.from(m['actions'] as List? ?? []),
  );
  List<AdminField> get editable => fields.where((f) => f.writable).toList();
}

class AdminRecord {
  final Map<String, dynamic> values;
  const AdminRecord(this.values);
  String id(AdminModule module) => values[module.pk].toString();
  String get revision => values['_revision'] as String? ?? '';
  String get title =>
      [
            values['name'],
            values['title'],
            values['subject'],
            values['question'],
            values['ticket_number'] == null
                ? null
                : 'Ticket #${values['ticket_number']}',
            values['document_type'],
            values['id'],
            values['booking_id'],
            values['audience'],
          ]
          .where((v) => v != null && v.toString().isNotEmpty)
          .firstOrNull
          ?.toString() ??
      'Record';
  String? related(String field) =>
      ((values['_relations'] as Map?)?[field] as Map?)?['label']?.toString();
  String display(String field) {
    final raw = values[field];
    return related(field) ??
        (raw == null
            ? '—'
            : raw is bool
            ? (raw ? 'Yes' : 'No')
            : raw is List
            ? raw.join(', ')
            : raw is Map
            ? const JsonEncoder.withIndent('  ').convert(raw)
            : raw.toString());
  }
}

class AdminPage {
  final int total;
  final List<AdminRecord> rows;
  const AdminPage({required this.total, required this.rows});
  factory AdminPage.fromMap(Map<String, dynamic> m) => AdminPage(
    total: (m['total'] as num).toInt(),
    rows: (m['rows'] as List)
        .map((r) => AdminRecord(Map<String, dynamic>.from(r as Map)))
        .toList(),
  );
}
