import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/models/admin_module.dart';
import 'package:admin/repositories/admin_repository.dart';
import 'package:admin/screens/management/admin_module_screen.dart';
import 'package:admin/widgets/admin_management_helpers.dart';

class FakeRepository implements AdminRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<AdminPage> records(String module, {String search = '', int offset = 0, int limit = 30, Map<String, dynamic> filters = const {}}) async => const AdminPage(total: 1, rows: [AdminRecord({'id': 'one', 'name': 'Eventra test vendor'})]);
}

void main() {
  test('Numeric inputs reject non-finite and fractional integers', () {
    const price = AdminField(name: 'price', type: 'numeric');
    const count = AdminField(name: 'guest_count', type: 'int4');
    expect(price.parse('120.50'), 120.5);
    expect(() => price.parse('NaN'), throwsFormatException);
    expect(() => price.parse('Infinity'), throwsFormatException);
    expect(() => count.parse('1.5'), throwsFormatException);
  });
  test('Booking actions respect the current lifecycle', () {
    const module = AdminModule(name: 'bookings', label: 'Bookings', section: 'Operations', actions: ['accepted', 'rejected', 'completed', 'cancelled']);
    expect(availableAdminActions(module, const AdminRecord({'status': 'pending'})), ['accepted', 'rejected', 'cancelled']);
    expect(availableAdminActions(module, const AdminRecord({'status': 'completed'})), isEmpty);
  });
  test('Account deletion needs owner access and review stage', () {
    const module = AdminModule(name: 'account_deletion_requests', label: 'Requests', section: 'Operations', actions: ['in_review', 'rejected', 'delete_account']);
    const record = AdminRecord({'status': 'in_review'});
    expect(availableAdminActions(module, record), isNot(contains('delete_account')));
    expect(availableAdminActions(module, record, owner: true), contains('delete_account'));
  });
  testWidgets('Mobile module loads records and hides viewer mutations', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeRepository();
    const module = AdminModule(name: 'vendors', label: 'Vendors', section: 'People', canCreate: true);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AdminModuleScreen(repo: repo, module: module, modules: const [module], canWrite: false))));
    await tester.pumpAndSettle();
    expect(find.text('Eventra test vendor'), findsOneWidget);
    expect(find.text('Add'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());

  });
}
