import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin/models/admin_module.dart';
import 'package:admin/repositories/admin_repository.dart';
import 'package:admin/screens/management/admin_customer_app_screen.dart';
import 'package:admin/screens/management/admin_module_screen.dart';
import 'package:admin/screens/management/admin_record_editor.dart';

class CustomerAdminRepository implements AdminRepository {
  Map<String, dynamic> lastFilters = {};
  Map<String, dynamic>? saved;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<AdminPage> records(
    String module, {
    String search = '',
    int offset = 0,
    int limit = 30,
    Map<String, dynamic> filters = const {},
  }) async {
    lastFilters = Map.from(filters);
    return const AdminPage(total: 0, rows: []);
  }

  @override
  Future<AdminRecord> save(
    AdminModule module,
    Map<String, dynamic> data, {
    AdminRecord? before,
    String? requestId,
  }) async {
    saved = Map.from(data);
    return AdminRecord({...data, 'id': 'saved'});
  }
}

const contacts = AdminModule(
  name: 'support_settings',
  label: 'Support Contact Settings',
  section: 'Support',
  pk: 'audience',
  canCreate: true,
  fields: [
    AdminField(
      name: 'audience',
      type: 'text',
      writable: true,
      required: true,
      nullable: false,
      choices: ['vendor', 'customer'],
    ),
    AdminField(name: 'email', type: 'text', writable: true),
    AdminField(name: 'whatsapp_number', type: 'text', writable: true),
  ],
);

void main() {
  testWidgets(
    'Customer hub opens customer privacy management with the correct filters',
    (tester) async {
      final repo = CustomerAdminRepository();
      String? target;
      Map<String, dynamic>? filters;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminCustomerAppScreen(
              repo: repo,
              modules: const [
                contacts,
                AdminModule(
                  name: 'legal_documents',
                  label: 'Terms & Privacy',
                  section: 'Content',
                ),
              ],
              onOpen: (module, values) {
                target = module;
                filters = values;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Complete customer support contacts'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Privacy Policy'), 250);
      await tester.tap(find.text('Privacy Policy'));
      expect(target, 'legal_documents');
      expect(filters, {
        'audience': 'customer',
        'document_type': 'privacy_policy',
      });
    },
  );

  testWidgets(
    'Shared audience remains a real filter and combines with active state',
    (tester) async {
      final repo = CustomerAdminRepository();
      const module = AdminModule(
        name: 'social_links',
        label: 'Follow Us Links',
        section: 'Content',
        canCreate: true,
        fields: [
          AdminField(
            name: 'audience',
            type: 'text',
            choices: ['vendor', 'customer', 'all'],
          ),
          AdminField(name: 'is_active', type: 'bool'),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminModuleScreen(
              repo: repo,
              module: module,
              modules: const [module],
              canWrite: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('social_links-audience-null')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Both apps').last);
      await tester.pumpAndSettle();
      expect(repo.lastFilters, {'audience': 'all'});
      await tester.tap(
        find.byKey(const ValueKey('social_links-is_active-null')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('No').last);
      await tester.pumpAndSettle();
      expect(repo.lastFilters, {'audience': 'all', 'is_active': false});
      expect(find.text('Add'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  Future<void> openContacts(
    WidgetTester tester,
    CustomerAdminRepository repo,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AdminRecordEditor(
                    repo: repo,
                    module: contacts,
                    modules: const [contacts],
                    initial: const {'audience': 'customer'},
                  ),
                ),
              ),
              child: const Text('Edit contacts'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit contacts'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Support contact editor rejects invalid email and phone numbers',
    (tester) async {
      final repo = CustomerAdminRepository();
      await openContacts(tester, repo);
      await tester.enterText(find.byType(TextFormField).at(0), 'bad-email');
      await tester.enterText(find.byType(TextFormField).at(1), 'invalid');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(repo.saved, isNull);
      expect(find.text('Enter a valid support email'), findsOneWidget);
      expect(
        find.text('Enter a phone number with country code (7–15 digits)'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'Support contact editor preserves customer audience and normalizes WhatsApp',
    (tester) async {
      final repo = CustomerAdminRepository();
      await openContacts(tester, repo);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'support@example.invalid',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        '+91 98765-43210',
      );
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(repo.saved?['audience'], 'customer');
      expect(repo.saved?['whatsapp_number'], '919876543210');
      expect(repo.saved?['email'], 'support@example.invalid');
    },
  );
}
