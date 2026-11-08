import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:eventor_vendor/models/administrative_region.dart';
import 'package:eventor_vendor/models/business_model.dart';
import 'package:eventor_vendor/models/shop_region_boundary.dart';
import 'package:eventor_vendor/repositories/business_workspace_repository.dart';
import 'package:eventor_vendor/screens/extended/business_details.dart';
import 'package:eventor_vendor/screens/extended/shop_location_picker.dart';

ShopRegionBoundary boundary() => ShopRegionBoundary.fromMap({
  'id': 't',
  'name': 'Test Taluk',
  'source_url': 'https://www.geoboundaries.org/',
  'source_year': 2018,
  'center': [11.01, 79.01],
  'geometry': {
    'type': 'MultiPolygon',
    'coordinates': [
      [
        [
          [79, 11],
          [79.04, 11],
          [79.04, 11.04],
          [79, 11.04],
          [79, 11],
        ],
        [
          [79.015, 11.015],
          [79.025, 11.015],
          [79.025, 11.025],
          [79.015, 11.025],
          [79.015, 11.015],
        ],
      ],
      [
        [
          [79.05, 11.05],
          [79.06, 11.05],
          [79.06, 11.06],
          [79.05, 11.06],
          [79.05, 11.05],
        ],
      ],
    ],
  },
});

class RegionRepo implements BusinessWorkspaceRepository {
  final calls = <String>[];
  Completer<List<AdministrativeRegion>>? pending;
  List<String>? savedCategories;
  final business = BusinessModel(
    id: 'b',
    vendorId: 'v',
    name: 'Test Business',
    primaryCategoryId: 'p',
    shopStateId: 's',
    shopDistrictId: 'd',
    shopSubdistrictId: 't',
    shopAddress: 'Shop address',
    latitude: 11.01,
    longitude: 79.01,
    isActive: true,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  @override
  Future<List<Map<String, dynamic>>> categories() async => [
    {'id': 'p', 'name': 'Parent One', 'parent_id': null},
    {'id': 'q', 'name': 'Parent Two', 'parent_id': null},
    {'id': 'c', 'name': 'Child Category', 'parent_id': 'p'},
  ];
  @override
  Future<List<String>> categoryIds(String id) async => ['p', 'q'];
  @override
  Future<List<AdministrativeRegion>> regions({
    required String level,
    String? parentId,
  }) async {
    calls.add('$level:$parentId');
    if (pending != null) return pending!.future;
    return [
      AdministrativeRegion(
        id: level == 'state'
            ? 's'
            : level == 'district'
            ? 'd'
            : 't',
        name: level == 'state'
            ? 'State One'
            : level == 'district'
            ? 'District One'
            : 'Taluk One',
        level: level,
        parentId: parentId,
      ),
    ];
  }

  @override
  Future<BusinessModel> save(
    String id,
    Map<String, dynamic> data,
    List<String> ids,
  ) async {
    savedCategories = ids;
    return business;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class LocalTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX5cAAAAASUVORK5CYII=',
        ),
      );
}

void main() {
  test('Polygon coverage handles holes, islands, edges and outside points', () {
    final b = boundary();
    expect(b.contains(const LatLng(11.01, 79.01)), true);
    expect(b.contains(const LatLng(11.02, 79.02)), false);
    expect(b.contains(const LatLng(11.055, 79.055)), true);
    expect(b.contains(const LatLng(11, 79.01)), true);
    expect(b.contains(const LatLng(12, 80)), false);
  });
  testWidgets(
    'Business dropdown allows one root category and preserves the saved primary',
    (tester) async {
      final repo = RegionRepo();
      await tester.pumpWidget(
        MaterialApp(
          home: AddBusinessScreen(business: repo.business, repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      final drop = find.byType(DropdownButtonFormField<String>);
      await tester.scrollUntilVisible(
        drop,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(drop), alignment: 0.3);
      await tester.pumpAndSettle();
      expect(find.byType(FilterChip), findsNothing);
      await tester.tap(drop);
      await tester.pumpAndSettle();
      expect(find.text('Child Category'), findsNothing);
      await tester.tap(find.text('Parent Two').last);
      await tester.pumpAndSettle();
      final selected = tester.widget<DropdownButtonFormField<String>>(drop);
      expect(selected.initialValue, 'q');

      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'District loading never moves the state/district fields and opens the right picker',
    (tester) async {
      final repo = RegionRepo();
      await tester.pumpWidget(
        MaterialApp(
          home: AddBusinessScreen(business: repo.business, repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      final district = find.byKey(const ValueKey('shop-district'));
      await tester.scrollUntilVisible(
        district,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(district), alignment: 0.3);
      await tester.pumpAndSettle();
      final before = tester.getTopLeft(district).dy;
      repo.pending = Completer<List<AdministrativeRegion>>();
      await tester.tap(district);
      await tester.pump();
      expect(tester.getTopLeft(district).dy, before);
      expect(repo.calls.last, 'district:s');
      repo.pending!.complete(const [
        AdministrativeRegion(
          id: 'd',
          name: 'District One',
          level: 'district',
          parentId: 's',
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Select district'), findsOneWidget);
      await tester.tap(find.text('District One').last);
      await tester.pumpAndSettle();
      expect(find.text('Edit Business'), findsOneWidget);
      repo.pending = null;
      final subdistrict = find.byKey(const ValueKey('shop-subdistrict'));
      await Scrollable.ensureVisible(tester.element(subdistrict), alignment: 0.3);
      await tester.pumpAndSettle();
      await tester.tap(subdistrict);
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'subdistrict:d');
      expect(find.text('Select sub-district'), findsOneWidget);
      await tester.tap(find.text('Taluk One').last);
      await tester.pumpAndSettle();
      expect(find.text('Edit Business'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Map rejects an outside existing pin and renders the real border',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ShopLocationPicker(
            boundary: boundary(),
            initialLocation: const LatLng(12, 80),
            tileProvider: LocalTiles(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Use this shop location'),
      );
      expect(button.onPressed, isNull);
      expect(find.byType(PolygonLayer), findsOneWidget);
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      map.options.onTap!(
        const TapPosition(Offset.zero, Offset.zero),
        const LatLng(11.01, 79.01),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Use this shop location'),
            )
            .onPressed,
        isNotNull,
      );
      map.options.onTap!(
        const TapPosition(Offset.zero, Offset.zero),
        const LatLng(11.02, 79.02),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Use this shop location'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
