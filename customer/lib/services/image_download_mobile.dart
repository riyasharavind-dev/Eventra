import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;

Future<void> downloadServiceImage(String url) async {
  if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
    throw StateError('Allow photo access to save this image.');
  }
  final response = await http
      .get(Uri.parse(url))
      .timeout(const Duration(seconds: 30));
  if (response.statusCode != 200 ||
      !(response.headers['content-type'] ?? '').startsWith('image/')) {
    throw StateError('Unable to download this image.');
  }
  if (response.bodyBytes.length > 25 * 1024 * 1024) {
    throw StateError('This image is too large to save.');
  }
  await Gal.putImageBytes(
    response.bodyBytes,
    name: 'Eventor-${DateTime.now().millisecondsSinceEpoch}',
  );
}
