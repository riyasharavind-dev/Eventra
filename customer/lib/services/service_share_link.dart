import 'package:flutter/foundation.dart';

/// Set CUSTOMER_PUBLIC_URL after deploying the customer web app.
Uri? serviceShareLink(
  String serviceId, {
  String publicUrl = const String.fromEnvironment('CUSTOMER_PUBLIC_URL'),
}) {
  final source = publicUrl.trim().isNotEmpty
      ? Uri.tryParse(publicUrl.trim())
      : kIsWeb
      ? Uri.base
      : null;
  if (source == null ||
      !['https', 'http'].contains(source.scheme) ||
      source.host.isEmpty) {
    return null;
  }
  return Uri(
    scheme: source.scheme,
    host: source.host,
    port: source.hasPort ? source.port : null,
    path: source.path,
    fragment: '/service/$serviceId',
  );
}
