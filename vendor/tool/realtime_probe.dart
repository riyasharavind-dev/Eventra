import 'dart:io';
import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:supabase/supabase.dart';

import 'package:eventor_vendor/core/config/supabase_config.dart';

Future<void> main() async {
  final client = SupabaseClient(SupabaseConfig.url, SupabaseConfig.anonKey);
  final ready = Completer<void>(), received = Completer<void>();
  final channel = client
      .channel('wire-probe-${DateTime.now().microsecondsSinceEpoch}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'app_data_revisions',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'dataset',
          value: '_live_probe',
        ),
        callback: (p) {
          if (p.newRecord['dataset'] == '_live_probe' &&
              !received.isCompleted) {
            received.complete();
          }
        },
      )
      .subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed &&
            !ready.isCompleted) {
          stdout.writeln('READY: subscribed to public revision probe');
          ready.complete();
        }
      });
  try {
    await ready.future.timeout(const Duration(seconds: 30));
    await received.future.timeout(const Duration(seconds: 60));
    stdout.writeln('PASS: live database revision received over WebSocket');
  } finally {
    await client.removeChannel(channel);
    await client.dispose();
  }
}
