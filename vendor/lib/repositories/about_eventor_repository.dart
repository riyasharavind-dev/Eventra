import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/about_eventor_model.dart';

class AboutEventorRepository {
  AboutEventorRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<AboutEventorModel?> getVendorAbout({
    String languageCode = 'en',
  }) async {
    final result = await _get(languageCode);
    if (result != null || languageCode == 'en') return result;
    return _get('en');
  }

  Future<AboutEventorModel?> _get(String languageCode) async {
    final result = await _client
        .from('published_about_eventra_content')
        .select('id, title, tagline, introduction, features')
        .eq('audience', 'vendor')
        .eq('language_code', languageCode)
        .maybeSingle();
    return result == null ? null : AboutEventorModel.fromMap(result);
  }
}
