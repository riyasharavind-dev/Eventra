import 'package:eventor_customer/services/app_live_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_customer/models/category_node_model.dart';
import 'package:eventor_customer/models/explore_data.dart';
import 'package:eventor_customer/models/service_model.dart';
import 'package:eventor_customer/repositories/explore_repository.dart';
import 'package:eventor_customer/screens/main/explore_screen.dart';
import 'package:eventor_customer/widgets/explore/explore_service_card.dart';

CategoryNodeModel category(String id, String name, [String? parent]) =>
    CategoryNodeModel(
      id: id,
      name: name,
      slug: id,
      parentId: parent,
      createdAt: DateTime.utc(2026),
    );
ServiceModel service(String id, String node, {String? name}) => ServiceModel(
  id: id,
  vendorId: 'vendor',
  categoryNodeId: node,
  name: name ?? id,
  slug: id,
  price: 1200.50,
  gallery: [],
  isActive: true,
  categoryName: 'Flower Decoration',
);

class PreviewExploreRepository implements ExploreRepository {
  PreviewExploreRepository(this.data);
  ExploreData data;
  bool fail = false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<ExploreData> load() async {
    if (fail) throw Exception('Offline');
    return data;
  }
}

void main() {
  late ExploreData data;
  setUp(
    () => data = ExploreData(
      categories: [
        category('decoration', 'Decoration'),
        category('flower', 'Flower Decoration', 'decoration'),
        category('rose', 'Rose Garland', 'flower'),
        category('catering', 'Catering'),
      ],
      services: [
        service('Flowers', 'flower'),
        service('Garlands', 'rose'),
        service('Food', 'catering'),
      ],
    ),
  );
  test('Parent categories include every descendant service', () {
    expect(data.parents.map((value) => value.name), ['Decoration', 'Catering']);
    expect(data.servicesFor('decoration').map((value) => value.id), [
      'Flowers',
      'Garlands',
    ]);
    expect(data.servicesFor('catering').map((value) => value.id), ['Food']);
    expect(data.servicesFor(null).length, 3);
    expect(data.servicesFor('missing'), isEmpty);
  });
  testWidgets(
    'Realtime updates Explore while retaining its selected parent category',
    (tester) async {
      final repo = PreviewExploreRepository(data);
      await tester.pumpWidget(
        MaterialApp(home: ExploreScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('parent-decoration')));
      await tester.pumpAndSettle();
      repo.data = ExploreData(
        categories: data.categories,
        services: [
          service('Live Flowers', 'flower'),
          service('Food', 'catering'),
        ],
      );
      AppLiveData.instance.invalidate({'public:services'});
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Live Flowers'), findsOneWidget);
      expect(find.text('Food'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Explore shows only parent categories, filters services, and opens a card',
    (tester) async {
      ServiceModel? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: ExploreScreen(
            repository: PreviewExploreRepository(data),
            onOpen: (value) => opened = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Explore'), findsOneWidget);
      expect(
        find.widgetWithText(ChoiceChip, 'Flower Decoration'),
        findsNothing,
      );
      for (final title in [
        'Popular Categories',
        'Explore by Event',
        'Featured Services',
        'Popular Near You',
        'Trending',
      ]) {
        expect(find.text(title), findsNothing);
      }
      await tester.tap(find.byKey(const ValueKey('parent-decoration')));
      await tester.pumpAndSettle();
      expect(find.text('Flowers'), findsOneWidget);
      expect(find.text('Garlands'), findsOneWidget);
      expect(find.text('Food'), findsNothing);
      await tester.tap(find.text('Flowers'));
      expect(opened?.id, 'Flowers');
      await tester.tap(find.byKey(const ValueKey('parent-all')));
      await tester.pumpAndSettle();
      expect(find.text('Food'), findsOneWidget);
    },
  );
  testWidgets('Explore lists services beyond the previous preview limits', (
    tester,
  ) async {
    final rows = ExploreData(
      categories: data.categories,
      services: [for (var i = 1; i <= 12; i++) service('Service $i', 'flower')],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ExploreScreen(repository: PreviewExploreRepository(rows)),
      ),
    );
    await tester.pumpAndSettle();
    final scrollable = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .last;
    await tester.scrollUntilVisible(
      find.text('Service 12'),
      400,
      scrollable: scrollable,
    );
    expect(find.text('Service 12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Service card handles narrow screens and enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: ExploreServiceCard(
                onView: () {},
                service: service(
                  'long',
                  'flower',
                  name: 'Wedding flower decoration and event planning service',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('₹1200.50'), findsOneWidget);
  });
  testWidgets('Explore recovers from an initial load error', (tester) async {
    final repository = PreviewExploreRepository(data)..fail = true;
    await tester.pumpWidget(
      MaterialApp(home: ExploreScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    repository.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Flowers'), findsOneWidget);
  });
}
