import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eventor_vendor/models/app_settings_model.dart';
import 'package:eventor_vendor/models/vendor_model.dart';
import 'package:eventor_vendor/models/profile_statistics.dart';
import 'package:eventor_vendor/screens/main/me_screen.dart';
import 'package:eventor_vendor/services/app_settings_controller.dart';
import 'package:eventor_vendor/services/app_live_data.dart';
import 'package:eventor_vendor/services/vendor_navigation_controller.dart';
import 'package:eventor_vendor/widgets/vendor_page_scaffold.dart';
import 'package:eventor_vendor/widgets/common/app_shimmer.dart';

void main() {
  testWidgets(
    'Me search keyboard preserves loaded state; initial/manual refresh covers the whole page',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = AppSettingsController(
        initial: const AppSettingsModel(),
        notificationPermission: () async => true,
      );
      final owner = Object();
      final nav = VendorNavigationController.instance;
      nav.attach(owner, (_) {}, selected: 3);
      var calls = 0;
      Completer<VendorModel?>? pendingVendor = Completer<VendorModel?>();
      Completer<ProfileStatistics>? pendingStats =
          Completer<ProfileStatistics>();
      const vendor = VendorModel(
        id: 'test-vendor',
        name: 'Test Vendor',
        email: 'test@example.invalid',
      );
      const stats = ProfileStatistics(
        completedEvents: 2,
        reviewCount: 3,
        rating: 4.5,
      );
      await tester.pumpWidget(
        AppSettingsScope(
          controller: settings,
          child: MaterialApp(
            home: VendorPageScaffold(
              reserveNavigationSpace: true,
              extendBody: true,
              body: MeScreen(
                loadVendor: () {
                  calls++;
                  return pendingVendor?.future ?? Future.value(vendor);
                },
                loadBusinesses: () async => [],
                loadSocialLinks: () async => [],
                loadStatistics: (_) =>
                    pendingStats?.future ?? Future.value(stats),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(calls, 1);
      expect(find.byType(AppContentSkeleton), findsOneWidget);
      expect(
        tester.getRect(find.byType(AppContentSkeleton)),
        tester.getRect(find.byType(AppShimmerRefreshIndicator)),
      );
      pendingVendor.complete(vendor);
      pendingVendor = null;
      await tester.pump();
      await tester.pump();
      // The full skeleton waits for statistics too, instead of exposing a loading card.
      expect(find.byType(AppContentSkeleton), findsOneWidget);
      pendingStats.complete(stats);
      pendingStats = null;
      await tester.pumpAndSettle();
      expect(find.byType(AppShimmer), findsNothing);
      await tester.tap(find.byType(TextField).first);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Language');
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Search results'), findsOneWidget);
      expect(find.byType(AppShimmer), findsNothing);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .controller
            .text,
        'Language',
      );
      await tester.enterText(find.byType(TextField).first, '');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      // A real database hint refreshes quietly, preserving visible content.
      AppLiveData.instance.invalidate({'own:vendors'});
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.byType(AppShimmer), findsNothing);
      pendingVendor = Completer<VendorModel?>();
      final refreshing = tester
          .widget<AppShimmerRefreshIndicator>(
            find.byType(AppShimmerRefreshIndicator),
          )
          .onRefresh();
      await tester.pump();
      expect(find.byType(AppContentSkeleton), findsOneWidget);
      expect(
        tester.getRect(find.byType(AppContentSkeleton)),
        tester.getRect(find.byType(AppShimmerRefreshIndicator)),
      );
      pendingVendor.complete(vendor);
      pendingVendor = null;
      await refreshing;
      await tester.pumpAndSettle();
      expect(find.byType(AppShimmer), findsNothing);
      expect(calls, 3);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      nav.detach(owner);
      await tester.pump();
      settings.dispose();
    },
  );
}
