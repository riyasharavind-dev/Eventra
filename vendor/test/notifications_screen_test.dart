import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eventor_vendor/models/vendor_notification.dart';
import 'package:eventor_vendor/repositories/vendor_notifications_repository.dart';
import 'package:eventor_vendor/screens/extended/notifications_screen.dart';

class InboxRepo extends VendorNotificationsRepository {
  InboxRepo()
    : super(client: SupabaseClient('https://example.supabase.co', 'test-key'));
  final items = <VendorNotification>[];
  bool fail = false;
  VoidCallback? changed;
  @override
  Future<void> syncAnnouncements() async {}
  @override
  Future<int> unreadCount() async => items.where((e) => e.unread).length;
  @override
  Future<List<VendorNotification>> load({
    String filter = 'all',
    VendorNotification? before,
  }) async {
    if (fail) throw Exception('private database error');
    var rows = items
        .where(
          (e) =>
              filter == 'all' ||
              filter == 'unread' && e.unread ||
              filter == e.kind ||
              filter == 'updates' && ['account', 'support'].contains(e.kind),
        )
        .toList();
    if (before != null) {
      rows = rows.skipWhile((e) => e.id != before.id).skip(1).toList();
    }
    return rows.take(VendorNotificationsRepository.pageSize).toList();
  }

  @override
  Future<void> markRead(VendorNotification item) async {
    final i = items.indexWhere((e) => e.id == item.id);
    items[i] = item.asRead(DateTime.now());
  }

  @override
  Future<void> markAllRead(DateTime before) async {
    for (var i = 0; i < items.length; i++) {
      items[i] = items[i].asRead(DateTime.now());
    }
  }

  @override
  RealtimeChannel watch(VoidCallback onChange) {
    changed = onChange;
    return db.channel('test');
  }

  @override
  Future<void> stopWatching(RealtimeChannel channel) async {}
}

VendorNotification notification(
  int id, {
  String kind = 'booking',
  DateTime? at,
}) => VendorNotification(
  id: '$id',
  kind: kind,
  title: 'Activity $id',
  body: 'Body $id',
  createdAt: at ?? DateTime.now().subtract(Duration(minutes: id)),
);
void main() {
  late InboxRepo repo;
  setUp(() => repo = InboxRepo());
  tearDown(() async => repo.db.dispose());
  Future<void> show(
    WidgetTester tester, {
    Future<void> Function(VendorNotification)? onOpen,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsScreen(
          repository: repo,
          onOpen: onOpen ?? (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('groups dates by local calendar day', () {
    final now = DateTime(2026, 10, 29, 0, 10);
    expect(notificationDateGroup(DateTime(2026, 10, 29), now), 'Today');
    expect(
      notificationDateGroup(DateTime(2026, 10, 28, 23, 59), now),
      'Yesterday',
    );
    expect(notificationDateGroup(DateTime(2026, 10, 25), now), 'This week');
    expect(notificationDateGroup(DateTime(2026, 9, 1), now), 'Earlier');
  });
  testWidgets('empty inbox and server error stay readable and retry works', (
    tester,
  ) async {
    repo.fail = true;
    await show(tester);
    expect(find.text('Unable to load notifications.'), findsOneWidget);
    expect(find.textContaining('private database'), findsNothing);
    repo.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('No notifications yet'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('opening activity persists read state and opens target', (
    tester,
  ) async {
    repo.items.add(notification(1));
    String? opened;
    await show(
      tester,
      onOpen: (item) async {
        opened = item.id;
      },
    );
    expect(find.text('Today'), findsOneWidget);
    await tester.tap(find.text('Activity 1'));
    await tester.pumpAndSettle();
    expect(opened, '1');
    expect(repo.items.single.unread, isFalse);
    expect(find.text('Mark all read'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('category filters and mark all read update the inbox', (
    tester,
  ) async {
    repo.items.addAll([notification(1), notification(2, kind: 'review')]);
    await show(tester);
    await tester.tap(find.text('Reviews'));
    await tester.pumpAndSettle();
    expect(find.text('Activity 2'), findsOneWidget);
    expect(find.text('Activity 1'), findsNothing);
    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();
    expect(repo.items.every((e) => !e.unread), isTrue);
    await tester.tap(find.text('Unread'));
    await tester.pumpAndSettle();
    expect(find.text('You’re all caught up'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('incoming activity appears without manual reload', (
    tester,
  ) async {
    await show(tester);
    repo.items.add(notification(1));
    repo.changed!();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Activity 1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('older pages are available beyond the first page', (
    tester,
  ) async {
    repo.items.addAll(List.generate(41, (i) => notification(i + 1)));
    await show(tester);
    await tester.scrollUntilVisible(
      find.text('Load older notifications'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Load older notifications'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Activity 41'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Activity 41'), findsOneWidget);
    repo.changed!();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Activity 41'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
