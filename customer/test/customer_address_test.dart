import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_customer/models/customer_address.dart';
import 'package:eventor_customer/repositories/customer_address_repository.dart';
import 'package:eventor_customer/screens/extended/customer_address_screen.dart';
import 'package:eventor_customer/screens/extended/customer_address_editor_screen.dart';

CustomerAddress address(String id, bool active) => CustomerAddress(
  id: id,
  label: id == 'home' ? 'Home' : 'Work',
  addressLine: '12 Main Street',
  area: 'Local Area',
  fullAddress: '$id, Local Area, Chennai',
  isActive: active,
);

class Addresses extends CustomerAddressRepository {
  List<CustomerAddress> entries = [
    address('home', true),
    address('work', false),
  ];
  String? activated;
  final regionCalls = <String>[];
  @override
  Future<List<CustomerAddress>> list() async => entries;
  @override
  Future<void> activate(String id) async {
    activated = id;
    entries = [for (final a in entries) address(a.id, a.id == id)];
  }

  @override
  Future<void> remove(String id) async {
    entries = entries.where((a) => a.id != id).toList();
    if (entries.isNotEmpty && !entries.any((a) => a.isActive)) {
      entries = [address(entries.first.id, true), ...entries.skip(1)];
    }
  }

  @override
  Future<List<AddressRegion>> regions(String level, {String? parentId}) async {
    regionCalls.add('$level:$parentId');
    if (level == 'state') {
      return const [
        AddressRegion(id: 'tn', name: 'Tamil Nadu'),
        AddressRegion(id: 'kl', name: 'Kerala'),
      ];
    }
    if (level == 'district') {
      return [
        AddressRegion(
          id: parentId == 'tn' ? 'chennai' : 'kochi',
          name: parentId == 'tn' ? 'Chennai' : 'Kochi',
        ),
      ];
    }
    return [];
  }
}

void main() {
  testWidgets('multiple addresses allow one active selection', (tester) async {
    final repo = Addresses();
    await tester.pumpWidget(
      MaterialApp(home: CustomerAddressScreen(repository: repo)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Active'), findsOneWidget);
    await tester.tap(find.text('Use this address'));
    await tester.pumpAndSettle();
    expect(repo.activated, 'work');
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
  });
  testWidgets(
    'state selection clears district and uses parent-scoped choices',
    (tester) async {
      final repo = Addresses();
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerAddressEditorScreen(
            repository: repo,
            firstAddress: true,
          ),
        ),
      );
      await tester.tap(find.text('Select State'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tamil Nadu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select District'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chennai'));
      await tester.pumpAndSettle();
      expect(repo.regionCalls, contains('district:tn'));
      await tester.tap(find.text('Tamil Nadu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kerala'));
      await tester.pumpAndSettle();
      expect(find.text('Select District'), findsOneWidget);
      expect(find.text('Select Sub-district'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
