import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_admin/models/admin_connections_model.dart';
import 'package:eventor_admin/models/admin_module.dart';
import 'package:eventor_admin/repositories/admin_connections_repository.dart';
import 'package:eventor_admin/repositories/admin_repository.dart';
import 'package:eventor_admin/screens/management/admin_connections_screen.dart';

class ConnectionsFake implements AdminConnectionsRepository {
  final offsets = <int>[];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<AdminConnections> inventory() async => AdminConnections(
    sources: [
      DatabaseConnection({
        'schema': 'public',
        'name': 'services',
        'module': 'services',
        'label': 'Services',
        'section': 'Businesses & Services',
        'kind': 'table',
        'rows': 2,
        'rls': true,
      }),
    ],
    buckets: [
      StorageConnection({
        'id': 'business-documents',
        'public': false,
        'objects': 31,
        'bytes': 1024,
        'max_bytes': 8388608,
        'mime_types': ['application/pdf'],
      }),
    ],
  );
  @override
  Future<AdminPage> objects(
    String bucket, {
    String query = '',
    int offset = 0,
  }) async {
    offsets.add(offset);
    return AdminPage(
      total: 31,
      rows: [
        AdminRecord({
          'id': 'file-$offset',
          'name': 'vendor/proof-$offset.pdf',
          'mime_type': 'application/pdf',
          'bytes': 1024,
        }),
      ],
    );
  }
}

class RepoFake implements AdminRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<String> signedFile(String bucket, String path) async =>
      'https://example.invalid/temporary-document';
}

void main() {
  testWidgets('Database module connections open their management route', (
    tester,
  ) async {
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminConnectionsScreen(
            connections: ConnectionsFake(),
            repo: RepoFake(),
            onOpen: (m, _) => opened = m,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('public.services'), findsOneWidget);
    await tester.tap(find.text('Services'));
    expect(opened, 'services');
    expect(tester.takeException(), isNull);
  });
  testWidgets('Private bucket preview and pagination work on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final connections = ConnectionsFake();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminConnectionsScreen(
            connections: connections,
            repo: RepoFake(),
            storageFirst: true,
            onOpen: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Private'), findsOneWidget);
    await tester.tap(find.text('Browse files'));
    await tester.pumpAndSettle();
    expect(find.text('vendor/proof-0.pdf'), findsOneWidget);
    await tester.tap(find.text('vendor/proof-0.pdf'));
    await tester.pumpAndSettle();
    expect(find.text('Copy 5-minute link'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(connections.offsets, [0, 30]);
    expect(find.text('vendor/proof-30.pdf'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
