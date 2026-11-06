import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vendor_notification.dart';

class VendorNotificationsRepository {
  VendorNotificationsRepository({SupabaseClient? client})
    : db = client ?? Supabase.instance.client;
  final SupabaseClient db;
  static const pageSize = 40;
  String get uid =>
      db.auth.currentUser?.id ?? (throw StateError('Please sign in again.'));
  Future<void> syncAnnouncements() async {
    await db.rpc('sync_vendor_announcements');
  }

  Future<int> unreadCount() async =>
      (await db.rpc('vendor_notification_unread_count') as num).toInt();
  Future<List<VendorNotification>> load({
    String filter = 'all',
    VendorNotification? before,
  }) async {
    var query = db
        .from('vendor_notifications')
        .select()
        .eq('recipient_id', uid);
    if (filter == 'unread') {
      query = query.isFilter('read_at', null);
    } else if (filter == 'updates') {
      query = query.inFilter('kind', ['account', 'support']);
    } else if (filter != 'all') {
      query = query.eq('kind', filter);
    }
    if (before != null) {
      final at = before.createdAt.toUtc().toIso8601String();
      query = query.or(
        'created_at.lt.$at,and(created_at.eq.$at,id.lt.${before.id})',
      );
    }
    final rows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(pageSize);
    return rows.map((r) => VendorNotification.fromMap(r)).toList();
  }

  Future<void> markRead(VendorNotification item) async {
    await db.rpc(
      'mark_vendor_notifications_read',
      params: {
        'p_ids': [item.id],
      },
    );
  }

  Future<void> markAllRead(DateTime before) async {
    await db.rpc(
      'mark_vendor_notifications_read',
      params: {'p_before': before.toUtc().toIso8601String()},
    );
  }

  RealtimeChannel watch(VoidCallback onChange) => db
      .channel('vendor-inbox-$uid-${DateTime.now().microsecondsSinceEpoch}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'vendor_notifications',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'recipient_id',
          value: uid,
        ),
        callback: (_) => onChange(),
      )
      .subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) onChange();
      });
  Future<void> stopWatching(RealtimeChannel channel) async {
    await db.removeChannel(channel);
  }
}
