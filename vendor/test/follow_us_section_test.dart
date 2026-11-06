import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vendor/models/app_settings_model.dart';
import 'package:vendor/models/social_link_model.dart';
import 'package:vendor/repositories/social_links_repository.dart';
import 'package:vendor/services/app_settings_controller.dart';
import 'package:vendor/widgets/follow_us_section.dart';

void main() {
  late AppSettingsController settings;
  setUp(
    () => settings = AppSettingsController(initial: const AppSettingsModel()),
  );
  tearDown(() => settings.dispose());
  Widget page(
    Future<List<SocialLinkModel>> Function() load, {
    int refresh = 0,
    Future<bool> Function(Uri)? open,
  }) => AppSettingsScope(
    controller: settings,
    child: MaterialApp(
      home: Scaffold(
        body: FollowUsSection(
          loadLinks: load,
          refreshKey: refresh,
          openLink: open,
        ),
      ),
    ),
  );

  testWidgets(
    'Fixed icons appear immediately while loading without a spinner',
    (tester) async {
      final pending = Completer<List<SocialLinkModel>>();
      await tester.pumpWidget(page(() => pending.future));
      expect(find.byTooltip('WhatsApp Community'), findsOneWidget);
      expect(find.byTooltip('Instagram'), findsOneWidget);
      expect(find.byTooltip('Facebook'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      pending.complete(const []);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Existing links stay visible and usable during a failed refresh',
    (tester) async {
      var calls = 0;
      final pending = Completer<List<SocialLinkModel>>();
      Future<List<SocialLinkModel>> load() {
        calls++;
        return calls == 1
            ? Future.value(const [
                SocialLinkModel(
                  id: 'instagram',
                  icon: 'instagram',
                  name: 'Instagram',
                  link: 'https://example.com/community',
                ),
              ])
            : pending.future;
      }

      Uri? opened;
      Future<bool> open(Uri uri) async {
        opened = uri;
        return true;
      }

      await tester.pumpWidget(page(load, open: open));
      await tester.pumpAndSettle();
      await tester.pumpWidget(page(load, refresh: 1, open: open));
      expect(find.byTooltip('Instagram'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      pending.completeError(Exception('Offline'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Instagram'), findsOneWidget);
      await tester.tap(find.byTooltip('Instagram'));
      await tester.pumpAndSettle();
      expect(opened.toString(), 'https://example.com/community');
    },
  );

  test('Stored links restore without a network request', () async {
    const link = SocialLinkModel(
      id: 'saved',
      icon: 'instagram',
      name: 'Saved Instagram',
      link: 'https://example.com/saved',
    );
    SharedPreferences.setMockInitialValues({
      'eventra.vendor.social_links.v1': jsonEncode([link.toMap()]),
    });
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-public-key',
    );
    final links = await SocialLinksRepository(client: client).readCache();
    expect(links.single.name, 'Saved Instagram');
    expect(links.single.link, 'https://example.com/saved');
    await client.dispose();
  });
}
