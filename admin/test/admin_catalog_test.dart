import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_admin/models/admin_module.dart';
import 'package:eventor_admin/repositories/admin_repository.dart';
import 'package:eventor_admin/screens/extended/admin_catalog_screen.dart';

class CatalogFakeRepository implements AdminRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const modules = [
    AdminModule(
      name: 'category_nodes',
      label: 'Categories',
      section: 'Catalog & Locations',
      canCreate: true,
    ),
    AdminModule(
      name: 'event_types',
      label: 'Event Types',
      section: 'Catalog & Locations',
      canCreate: true,
    ),
  ];
  testWidgets('Catalog management buttons open the correct existing modules', (
    tester,
  ) async {
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminCatalogScreen(
            repo: CatalogFakeRepository(),
            modules: modules,
            canWrite: (_) => true,
            onOpen: (name, filters) => opened = name,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage Categories'));
    expect(opened, 'category_nodes');
    await tester.ensureVisible(find.text('Manage Event Types'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage Event Types'));
    expect(opened, 'event_types');
    expect(find.text('Create Category'), findsOneWidget);
    expect(find.text('Create Event Type'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Scoped read-only staff see only assigned modules and no create action',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminCatalogScreen(
              repo: CatalogFakeRepository(),
              modules: [modules.first],
              canWrite: (_) => false,
              onOpen: (_, filters) {},
            ),
          ),
        ),
      );
      expect(find.text('Manage Categories'), findsOneWidget);
      expect(find.text('Manage Event Types'), findsNothing);
      expect(find.text('Create Category'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
