import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_customer/models/category_node_model.dart';
import 'package:eventor_customer/models/explore_data.dart';
import 'package:eventor_customer/models/service_model.dart';
import 'package:eventor_customer/repositories/explore_repository.dart';
import 'package:eventor_customer/screens/main/explore_screen.dart';
import 'package:eventor_customer/widgets/explore/explore_service_card.dart';
import 'package:eventor_customer/widgets/explore/explore_categories.dart';
import 'package:eventor_customer/screens/extended/result_screen.dart';
import 'package:eventor_customer/widgets/home_feed_widgets.dart';

import 'category_result_test_repository.dart';

CategoryNodeModel category(String id, String name, [String? parent]) =>
    CategoryNodeModel(
      id: id,
      name: name,
      slug: id,
      parentId: parent,
      createdAt: DateTime(2026),
    );
ServiceModel service(String id, String category) => ServiceModel(
  id: id,
  vendorId: 'v',
  categoryNodeId: category,
  name: 'Service $id',
  slug: id,
  price: 100,
  gallery: const [],
  isActive: true,
);
final data = ExploreData(
  categories: [
    category('decor', 'Decoration'),
    category('flower', 'Flowers', 'decor'),
    category('rose', 'Roses', 'flower'),
    category('music', 'Music'),
  ],
  services: [
    service('rose-service', 'rose'),
    service('music-service', 'music'),
  ],
);

class FakeExplore implements ExploreRepository {
  bool fail = false;
  @override
  Future<ExploreData> load() async {
    if (fail) throw StateError('offline');
    return data;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'Tree filtering includes all descendants and generates category path',
    () {
      expect(data.servicesFor('decor').map((s) => s.id), ['rose-service']);
      expect(data.servicesFor('flower').map((s) => s.id), ['rose-service']);
      expect(data.pathFor('rose').map((c) => c.id), [
        'decor',
        'flower',
        'rose',
      ]);
      expect(data.childrenFor('decor').map((c) => c.id), ['flower']);
    },
  );
  testWidgets(
    'Explore shows all descendants together; services open only after choosing a type',
    (tester) async {
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: ExploreScreen(
            repository: FakeExplore(),
            resultRepository: CategoryResultTestRepository(data),
            onOpen: (s) => opened = s.id,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Explore'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('parent-decor')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('child-flower')), findsOneWidget);
      expect(find.byKey(const ValueKey('child-rose')), findsOneWidget);
      expect(find.byType(ExploreCategoryTrail), findsNothing);
      expect(find.byType(ExploreServiceCard), findsNothing);
      await tester.tap(find.byKey(const ValueKey('child-rose')));
      await tester.pumpAndSettle();
      expect(find.byType(ResultScreen), findsOneWidget);
      expect(find.byType(HomeFeedItemCard), findsOneWidget);
      await tester.ensureVisible(find.byType(HomeFeedItemCard));
      await tester.tap(find.byType(HomeFeedItemCard));
      expect(opened, 'rose-service');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Explore fits a narrow screen with large text and supports retry',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeExplore()..fail = true;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: ExploreScreen(
            repository: repo,
            resultRepository: CategoryResultTestRepository(data),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      repo.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('parent-decor')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('child-flower')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
