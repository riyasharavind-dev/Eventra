import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_customer/models/service_review_model.dart';
import 'package:eventor_customer/widgets/reviews/service_review_card.dart';

void main() {
  testWidgets('review comment card fits narrow screens and enlarged text', (
    tester,
  ) async {
    final review = ServiceReviewModel(
      id: 'r',
      serviceId: 's',
      vendorId: 'v',
      customerName: 'A very long customer display name',
      serviceName: 'Service',
      text: 'Excellent service with a detailed customer comment that wraps naturally.',
      rating: 5,
      createdAt: DateTime(2026, 11, 10),
      updatedAt: DateTime(2026, 11, 10),
    );
    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: SizedBox(
                width: 288,
                child: ServiceReviewCard(review: review),
              ),
            ),
          ),
        ),
      );
      expect(find.text(review.text), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
  test('review model reads uploaded photo references', () {
    final review = ServiceReviewModel.fromMap({
      'id': 'r',
      'service_id': 's',
      'vendor_id': 'v',
      'rating': 4,
      'created_at': '2026-11-10T00:00:00Z',
      'updated_at': '2026-11-10T00:00:00Z',
      'photo_paths': ['owner/booking/photo.jpg'],
      'photo_urls': ['https://example.com/photo.jpg'],
    });
    expect(review.photoPaths, ['owner/booking/photo.jpg']);
    expect(review.photoUrls, ['https://example.com/photo.jpg']);
  });
}
