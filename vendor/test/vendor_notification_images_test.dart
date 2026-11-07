import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_vendor/models/vendor_notification.dart';
import 'package:eventor_vendor/widgets/notifications/notification_tile.dart';

void main() {
  VendorNotification item({
    String? image,
    Map<String, dynamic> data = const {},
  }) => VendorNotification(
    id: 'test',
    kind: 'booking',
    title: 'Booking alert',
    body: 'A service booking update.',
    createdAt: DateTime(2026, 11, 7),
    imageUrl: image,
    data: data,
  );
  test(
    'Image survives read state changes and supports existing JSON payloads',
    () {
      final value = item(image: 'https://example.invalid/service.png');
      expect(value.asRead(DateTime.now()).thumbnailUrl, value.thumbnailUrl);
      expect(
        item(data: {'image_url': 'https://example.invalid/banner.png'})
            .thumbnailUrl,
        'https://example.invalid/banner.png',
      );
    },
  );
  test('Unsafe or malformed image URLs fall back to the notification icon', () {
    for (final image in [
      'javascript:alert(1)',
      'file:///secret.png',
      'https://user:password@example.invalid/image.png',
      'not-a-url',
    ]) {
      expect(item(image: image).thumbnailUrl, isNull);
    }
  });
  testWidgets('Image-less alerts retain their text and tap action', (
    tester,
  ) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationTile(item: item(), onTap: () => tapped = true),
        ),
      ),
    );
    expect(find.text('Booking alert'), findsOneWidget);
    expect(find.byIcon(Icons.event_available_outlined), findsOneWidget);
    await tester.tap(find.text('Booking alert'));
    expect(tapped, true);
    expect(tester.takeException(), isNull);
  });
}
