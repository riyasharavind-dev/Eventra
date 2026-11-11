import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_customer/widgets/service_details/service_gallery.dart';
import 'package:eventor_customer/services/service_share_link.dart';

void main() {
  test('share links require a real base URL and remove query secrets', () {
    expect(serviceShareLink('service', publicUrl: ''), isNull);
    expect(serviceShareLink('service', publicUrl: 'not-a-url'), isNull);
    final link = serviceShareLink(
      'service',
      publicUrl: 'https://customer.example/app/?token=private',
    );
    expect(link.toString(), 'https://customer.example/app/#/service/service');
    expect(link!.query, isEmpty);
  });
  testWidgets('photos auto-loop forwards and expose share action', (
    tester,
  ) async {
    var shared = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ServiceGallery(
            gallery: const [
              'https://example.com/1.jpg',
              'https://example.com/2.jpg',
              'https://example.com/3.jpg',
            ],
            onShare: () => shared++,
          ),
        ),
      ),
    );
    expect(find.text('1 / 3'), findsOneWidget);
    for (final next in ['2 / 3', '3 / 3', '1 / 3']) {
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(next), findsOneWidget);
    }
    await tester.tap(find.byTooltip('Share service'));
    expect(shared, 1);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
