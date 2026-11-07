import 'dart:js_interop';

@JS('window.history.replaceState')
external void _replaceState(JSAny? data, JSString title, JSString url);
void clearAdminAuthUrl() => _replaceState(null, ''.toJS, '/'.toJS);

void setAdminAuthAction(String? action) => _replaceState(
  null,
  ''.toJS,
  ((action == 'setup' || action == 'recovery') ? '/?auth_action=$action' : '/')
      .toJS,
);
