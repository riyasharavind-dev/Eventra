/// Untrusted URL hints determine the screen, never authorization. Supabase Auth
/// must verify the callback credentials before any reset form can be used.
class AdminAuthLink {
  final Uri uri;
  final String? action;
  final bool hasCredentials;
  final bool hasError;
  const AdminAuthLink._(
    this.uri,
    this.action,
    this.hasCredentials,
    this.hasError,
  );

  factory AdminAuthLink.parse(Uri uri) {
    var fragment = uri.fragment;
    if (fragment.contains('?')) {
      fragment = fragment.substring(fragment.indexOf('?') + 1);
    }
    Map<String, String> fragmentValues;
    try {
      fragmentValues = Uri.splitQueryString(fragment);
    } on FormatException {
      fragmentValues = {};
    }
    final values = {...fragmentValues, ...uri.queryParameters};
    final hint = values['auth_action'];
    final type = values['type'];
    final action = hint == 'setup' || type == 'invite'
        ? 'setup'
        : hint == 'recovery' || type == 'recovery'
        ? 'recovery'
        : null;
    return AdminAuthLink._(
      uri,
      action,
      (values['code']?.isNotEmpty ?? false) ||
          (values['access_token']?.isNotEmpty ?? false),
      ['error', 'error_code', 'error_description'].any(values.containsKey),
    );
  }
}
