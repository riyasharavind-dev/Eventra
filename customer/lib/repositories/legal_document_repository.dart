import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/legal_document_model.dart';

class LegalDocumentRepository {
  LegalDocumentRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<LegalDocumentModel?> getCustomerTerms({String languageCode = 'en'}) {
    return _getWithFallback('terms_and_conditions', languageCode);
  }

  Future<LegalDocumentModel?> getCustomerPrivacyPolicy({
    String languageCode = 'en',
  }) {
    return _getWithFallback('privacy_policy', languageCode);
  }

  Future<LegalDocumentModel?> _getWithFallback(
    String documentType,
    String languageCode,
  ) async {
    final requested = await _getDocument(documentType, languageCode);
    if (requested != null || languageCode == 'en') return requested;
    return _getDocument(documentType, 'en');
  }

  Future<LegalDocumentModel?> _getDocument(
    String documentType,
    String languageCode,
  ) async {
    // The database view excludes drafts and not-yet-effective publications.
    final result = await _client
        .from('current_legal_documents')
        .select(
          'id, document_type, audience, language_code, version, title, '
          'content_markdown, effective_at, published_at',
        )
        .eq('document_type', documentType)
        .eq('audience', 'customer')
        .eq('language_code', languageCode)
        .maybeSingle();

    if (result == null) return null;
    return LegalDocumentModel.fromMap(result);
  }
}
