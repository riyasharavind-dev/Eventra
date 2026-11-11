import 'dart:js_interop';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

Future<void> downloadServiceImage(String url) async {
  final response = await http
      .get(Uri.parse(url))
      .timeout(const Duration(seconds: 30));
  final mime = response.headers['content-type'] ?? '';
  if (response.statusCode != 200 || !mime.startsWith('image/')) {
    throw StateError('Unable to download this image.');
  }
  if (response.bodyBytes.length > 25 * 1024 * 1024) {
    throw StateError('This image is too large to save.');
  }
  final blob = web.Blob(
    [Uint8List.fromList(response.bodyBytes).toJS].toJS,
    web.BlobPropertyBag(type: mime),
  );
  final objectUrl = web.URL.createObjectURL(blob);
  final ext = mime.contains('png')
      ? 'png'
      : mime.contains('webp')
      ? 'webp'
      : 'jpg';
  final anchor = web.HTMLAnchorElement()
    ..href = objectUrl
    ..download = 'Eventor-${DateTime.now().millisecondsSinceEpoch}.$ext';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  Future<void>.delayed(
    const Duration(seconds: 30),
    () => web.URL.revokeObjectURL(objectUrl),
  );
}
