import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_vendor/widgets/common/app_shimmer.dart';
import 'package:eventor_vendor/widgets/common/global_search_bar.dart';

void main() {
  testWidgets('Every skeleton fits narrow viewports and compact action slots', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final layout in SkeletonLayout.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AppContentSkeleton(layout: layout)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(AppShimmer), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull, reason: '$layout');
    }
    for (final size in [12.0, 18.0, 22.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.square(
                dimension: size,
                child: const AppShimmerIndicator(color: Colors.white),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Reduced motion stops the shimmer animation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: AppShimmer(child: const SkeletonBox(width: 100, height: 20)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final animation =
        tester
                .widget<AnimatedBuilder>(
                  find.descendant(
                    of: find.byType(AppShimmer),
                    matching: find.byType(AnimatedBuilder),
                  ),
                )
                .animation
            as AnimationController;
    expect(animation.isAnimating, isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Pull to refresh uses shimmer and completes normally', (
    tester,
  ) async {
    final completed = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppShimmerRefreshIndicator(
            onRefresh: () {
              calls++;
              return completed.future;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [SizedBox(height: 1000)],
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, 1);
    expect(find.byType(ShimmerLoadingBar), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    completed.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ShimmerLoadingBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'search taps and small pulls stay idle; only top pull refreshes',
    (tester) async {
      var calls = 0;
      final search = TextEditingController();
      final scroll = ScrollController();
      final completed = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppShimmerRefreshIndicator(
              onRefresh: () {
                calls++;
                return completed.future;
              },
              child: ListView(
                controller: scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  GlobalSearchBar(
                    controller: search,
                    onChanged: (_) {},
                    hintText: 'Search',
                  ),
                  const SizedBox(height: 1600),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'decoration');
      await tester.pump();
      expect(search.text, 'decoration');
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(calls, 0);
      expect(find.byType(ShimmerLoadingBar), findsNothing);
      FocusManager.instance.primaryFocus?.unfocus();
      // ScrollStart alone must never look like a running refresh.
      final gesture = await tester.startGesture(const Offset(200, 250));
      await gesture.moveBy(const Offset(0, 25));
      await tester.pump();
      expect(find.byType(ShimmerLoadingBar), findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(calls, 0);
      // A downward drag in the middle of the list cannot refresh it.
      scroll.jumpTo(700);
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.byType(ShimmerLoadingBar), findsNothing);
      scroll.jumpTo(0);
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(calls, 1);
      expect(find.byType(ShimmerLoadingBar), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // Existing content and search remain usable while refreshing.
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'catering');
      expect(search.text, 'catering');
      expect(calls, 1);
      completed.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ShimmerLoadingBar), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      search.dispose();
      scroll.dispose();
    },
  );
}
