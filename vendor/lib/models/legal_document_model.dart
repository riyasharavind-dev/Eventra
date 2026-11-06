class LegalDocumentModel {
  const LegalDocumentModel({
    required this.id,
    required this.documentType,
    required this.audience,
    required this.languageCode,
    required this.version,
    required this.title,
    required this.contentMarkdown,
    required this.effectiveAt,
    required this.publishedAt,
  });

  final String id;
  final String documentType;
  final String audience;
  final String languageCode;
  final int version;
  final String title;
  final String contentMarkdown;
  final DateTime effectiveAt;
  final DateTime publishedAt;

  factory LegalDocumentModel.fromMap(Map<String, dynamic> map) {
    return LegalDocumentModel(
      id: map['id'] as String,
      documentType: map['document_type'] as String,
      audience: map['audience'] as String,
      languageCode: map['language_code'] as String,
      version: (map['version'] as num).toInt(),
      title: map['title'] as String,
      contentMarkdown: map['content_markdown'] as String,
      effectiveAt: DateTime.parse(map['effective_at'] as String),
      publishedAt: DateTime.parse(map['published_at'] as String),
    );
  }
}
