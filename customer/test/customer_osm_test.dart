import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:eventor_customer/services/location_picker_screen.dart';

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
  testWidgets(
    'OSM picker confirms initial coordinates with the same return contract',
    (tester) async {
      Map<String, dynamic>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.push<Map<String, dynamic>>(
                    c,
                    MaterialPageRoute(
                      builder: (_) => LocationPickerScreen(
                        initialLocation: 'Test Hall',
                        initialCoordinates: const LatLng(11, 79),
                        tileProvider: LocalTiles(),
                      ),
                    ),
                  );
                },
                child: const Text('Pick'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm Location'));
      await tester.pumpAndSettle();
      expect(result, {
        'latitude': 11.0,
        'longitude': 79.0,
        'address': 'Test Hall',
      });
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Map tap selects a point without requiring GPS permission', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LocationPickerScreen(
          initialLocation: 'Test Hall',
          tileProvider: LocalTiles(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm Location'));
    await tester.pump();
    expect(
      find.text('Tap or move the map to select the exact location.'),
      findsOneWidget,
    );
    final map = tester.getRect(find.byType(FlutterMap));
    await tester.tapAt(map.center + const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Event Location'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Updated Hall');
    await tester.tap(find.text('Use Location'));
    await tester.pumpAndSettle();
    expect(find.text('Updated Hall'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
