import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_customer/models/service_recommendations.dart';
import 'package:eventor_customer/repositories/recommendation_repository.dart';
import 'package:eventor_customer/widgets/recommendations/service_recommendations_section.dart';

class VendorRecommendations implements RecommendationRepository {
  int calls = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<RecommendationPage> relatedVendorsPage({
    required String serviceId,
    int offset = 0,
  }) async {
    calls++;
    return RecommendationPage({
      'items': [
        {
          'id': 'vendor',
          'type': 'vendors',
          'name': 'Related Vendor',
          'business_name': 'Related Business',
          'location': 'Thanjavur',
          'completed_count': 42,
          'review_count': 10,
          'rating': 4.8,
        },
      ],
      'next_offset': 1,
      'has_more': false,
    });
  }
}

void main() {
  testWidgets('related vendor shelf uses vendor endpoint and vendor card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = VendorRecommendations();
    final controller = RecommendationController(
      repository: repo,
      serviceId: 'anchor',
      vendors: true,
    );
    await controller.refresh();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ServiceRecommendationsSection(controller: controller),
          ),
        ),
      ),
    );
    expect(repo.calls, 1);
    expect(find.text('Related vendors'), findsOneWidget);
    expect(find.text('Related Business'), findsOneWidget);
    expect(find.text('Thanjavur'), findsOneWidget);
    expect(find.text('42 events completed'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
