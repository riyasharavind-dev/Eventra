import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:eventor_vendor/models/service_model.dart';
import 'package:eventor_vendor/models/listing_filter.dart';
import 'package:eventor_vendor/widgets/listings/listing_ui.dart';

ServiceModel service(String id, {bool archived = false, bool active = true}) =>
    ServiceModel(
      id: id,
      vendorId: 'vendor',
      categoryNodeId: 'decor',
      name: 'Wedding stage decoration with flowers',
      slug: id,
      description: 'Custom floral stage setup for your wedding celebrations.',
      price: 25000,
      gallery: [],
      isActive: active && !archived,
      isArchived: archived,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
void main() {
  test(
    'archive survives model roundtrip and remains separate from deactivation',
    () {
      final archived = service('archived', archived: true);
      expect(ServiceModel.fromMap(archived.toMap()).isArchived, true);
      expect(archived.copyWith(name: 'Changed').isArchived, true);
      final rows = [
        service('active'),
        service('inactive', active: false),
        archived,
      ];
      expect(filterListings(rows, status: 'inactive').map((s) => s.id), [
        'inactive',
      ]);
      expect(filterListings(rows, status: 'archived').map((s) => s.id), [
        'archived',
      ]);
      expect(filterListings(rows, status: 'active').map((s) => s.id), [
        'active',
      ]);
    },
  );
  testWidgets(
    'two-column pins stagger, fit large text, and expose archive actions',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? action;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(12),
                    sliver: SliverMasonryGrid.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childCount: 3,
                      itemBuilder: (_, i) => ListingCard(
                        key: ValueKey('pin-$i'),
                        service: service('$i', archived: i == 2),
                        photoAspectRatio: i == 0 ? 0.7 : 1.2,
                        bookingCount: 3,
                        rating: 4.7,
                        onOpen: () {},
                        onAction: (value) => action = value,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first = tester.getRect(find.byKey(const ValueKey('pin-0')));
      final second = tester.getRect(find.byKey(const ValueKey('pin-1')));
      final third = tester.getRect(find.byKey(const ValueKey('pin-2')));
      expect(first.height, greaterThan(second.height));
      expect(third.left, second.left);
      expect(third.top, lessThan(first.bottom + 12));
      expect(find.byType(ColorFiltered), findsOneWidget);
      expect(find.text('Wedding stage decoration with flowers'), findsNothing);
      expect(
        find.text('Custom floral stage setup for your wedding celebrations.'),
        findsNothing,
      );
      final menu = tester.widget<PopupMenuButton<String>>(
        find.byType(PopupMenuButton<String>).first,
      );
      expect(menu.style!.backgroundColor!.resolve({}), Colors.transparent);
      final ratios = tester
          .widgetList<AspectRatio>(find.byType(AspectRatio))
          .map((w) => w.aspectRatio)
          .toSet();
      expect(ratios.length, greaterThan(1));

      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      expect(find.text('Edit service'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Deactivate'), findsOneWidget);
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(action, 'archive');
      await tester.ensureVisible(find.byKey(const ValueKey('pin-2')));
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('pin-2')),
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Restore'), findsOneWidget);
      expect(find.text('Activate'), findsNothing);
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(action, 'restore');
      expect(tester.takeException(), isNull);
    },
  );
}
