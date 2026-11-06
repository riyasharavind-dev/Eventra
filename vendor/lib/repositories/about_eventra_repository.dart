import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/about_eventra_model.dart';

class AboutEventraRepository {
  AboutEventraRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<AboutEventraModel?> getVendorAbout({
    String languageCode = 'en',
  }) async {
    final result = await _get(languageCode);
    if (result != null || languageCode == 'en') return result;
    return _get('en');
  }

  Future<AboutEventraModel?> _get(String languageCode) async {
    final result = await _client
        .from('published_about_eventra_content')
        .select('id, title, tagline, introduction, features')
        .eq('audience', 'vendor')
        .eq('language_code', languageCode)
        .maybeSingle();
    return result == null ? null : AboutEventraModel.fromMap(result);
  }
}
