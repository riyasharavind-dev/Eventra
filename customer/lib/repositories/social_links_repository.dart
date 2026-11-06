import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/social_link_model.dart';

class SocialLinksRepository {
  SocialLinksRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;
  static const _cacheKey = 'eventra.customer.social_links.v1';
  static const defaults = <SocialLinkModel>[
    SocialLinkModel(
      id: 'whatsapp',
      icon: 'whatsapp',
      name: 'WhatsApp Community',
    ),
    SocialLinkModel(id: 'instagram', icon: 'instagram', name: 'Instagram'),
    SocialLinkModel(id: 'facebook', icon: 'facebook', name: 'Facebook'),
  ];
  static List<SocialLinkModel> _cached = defaults;
  static bool _hasCache = false;
  static List<SocialLinkModel> get cachedLinks => _cached;

  Future<List<SocialLinkModel>> readCache() async {
    if (_hasCache) return _cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      final text = prefs.getString(_cacheKey);
      if (text != null && !_hasCache) {
        final rows = jsonDecode(text) as List;
        _cached = List.unmodifiable(
          rows.map(
            (row) =>
                SocialLinkModel.fromMap(Map<String, dynamic>.from(row as Map)),
          ),
        );
        _hasCache = true;
      }
    } catch (_) {
      /* Keep the fixed icons if the cache is unavailable. */
    }
    return _cached;
  }

  Future<List<SocialLinkModel>> getLinks() async {
    final rows = await _client
        .from('active_social_links')
        .select('id, icon, icon_url, name, link')
        .inFilter('audience', ['customer', 'all'])
        .order('sort_order')
        .order('name')
        .timeout(const Duration(seconds: 12));
    final links = List<SocialLinkModel>.unmodifiable(
      rows.map(SocialLinkModel.fromMap),
    );
    _cached = links;
    _hasCache = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode(links.map((link) => link.toMap()).toList()),
      );
    } catch (_) {
      /* Memory cache still provides the current links. */
    }
    return links;
  }
}
