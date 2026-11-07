import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_admin/models/admin_module.dart';
import 'package:eventor_admin/repositories/admin_repository.dart';
import 'package:eventor_admin/screens/extended/admin_workspace_screen.dart';
import 'package:eventor_admin/screens/management/admin_record_screen.dart';
import 'package:eventor_admin/screens/management/admin_module_screen.dart';
import 'package:eventor_admin/widgets/admin_management_helpers.dart';

class WorkspaceFakeRepository implements AdminRepository {
  bool deleted = false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<AdminPage> records(
    String module, {
    String search = '',
    int offset = 0,
    int limit = 30,
    Map<String, dynamic> filters = const {},
  }) async => const AdminPage(
    total: 1,
    rows: [
      AdminRecord({'id': 'sample-record', 'question': 'Test FAQ'}),
    ],
  );
  @override
  Future<AdminRecord> record(AdminModule module, String id) async =>
      const AdminRecord({
        'id': 'sample-record',
        'question': 'Test FAQ',
        '_revision': 'revision-one',
      });
  @override
  Future<Map<String, dynamic>> deleteRecord(
    AdminModule module,
    AdminRecord record,
    String reason,
    String confirmation,
  ) async {
    deleted = true;
    return {'deleted': true};
  }
}

void main() {
  const faq = AdminModule(
    name: 'support_faqs',
    label: 'Help FAQs',
    section: 'Support',
    description: 'Manage help content.',
    canCreate: true,
    canDelete: true,
    fields: [AdminField(name: 'question', type: 'text', writable: true)],
  );
  const history = AdminModule(
    name: 'booking_status_history',
    label: 'Booking History',
    section: 'Bookings & History',
    managementMode: 'history',
    description: 'Retained event history.',
  );
  testWidgets(
    'Mobile workspace searches connected modules and opens the selected one',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminWorkspaceScreen(
              modules: const [faq, history],
              canWrite: (_) => true,
              onOpen: (name, filters) => opened = name,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'faq');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Help FAQs'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Help FAQs'));
      expect(opened, 'support_faqs');
      expect(find.text('Booking History'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Owner delete validates reason and exact ID before calling the repository',
    (tester) async {
      final repo = WorkspaceFakeRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => AdminRecordScreen(
                      repo: repo,
                      module: faq,
                      modules: const [faq],
                      id: 'sample-record',
                      isOwner: true,
                    ),
                  ),
                ),
                child: const Text('Open fixture'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open fixture'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete record'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete permanently'));
      await tester.pumpAndSettle();
      expect(repo.deleted, false);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Reason'),
        'Remove test fixture',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Type the exact record ID'),
        'sample-record',
      );
      await tester.tap(find.text('Delete permanently'));
      await tester.pumpAndSettle();
      expect(repo.deleted, true);
      expect(find.text('Open fixture'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Non-owner cannot access delete even when module metadata permits it',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminRecordScreen(
            repo: WorkspaceFakeRepository(),
            module: faq,
            modules: const [faq],
            id: 'sample-record',
            isOwner: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Delete record'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  test('Account lifecycle actions respect owner access, suspension and admin protection', () {
    const module = AdminModule(
      name: 'users',
      label: 'Accounts',
      section: 'Accounts & Access',
      actions: ['suspend_account', 'restore_account'],
    );
    expect(
      availableAdminActions(
        module,
        const AdminRecord({'_account_suspended': false}),
        owner: true,
      ),
      ['suspend_account'],
    );
    expect(
      availableAdminActions(
        module,
        const AdminRecord({'_account_suspended': true}),
        owner: true,
      ),
      ['restore_account'],
    );
    expect(
      availableAdminActions(
        module,
        const AdminRecord({'_managed_admin': true}),
        owner: true,
      ),
      isEmpty,
    );
    expect(
      availableAdminActions(module, const AdminRecord({}), owner: false),
      isEmpty,
    );
  });
  testWidgets(
    'Long filter controls scroll within a short mobile module screen',
    (tester) async {
      tester.view.physicalSize = const Size(390, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const module = AdminModule(
        name: 'support_faqs',
        label: 'Help FAQs',
        section: 'Support',
        fields: [
          AdminField(name: 'audience', type: 'text'),
          AdminField(name: 'language_code', type: 'text'),
          AdminField(name: 'document_type', type: 'text'),
          AdminField(name: 'sender_role', type: 'text'),
          AdminField(name: 'is_published', type: 'bool'),
          AdminField(name: 'is_active', type: 'bool'),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminModuleScreen(
              repo: WorkspaceFakeRepository(),
              module: module,
              modules: const [module],
              canWrite: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Test FAQ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
