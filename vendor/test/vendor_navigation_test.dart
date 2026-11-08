import 'package:eventor_vendor/widgets/common/expandable_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_vendor/services/vendor_navigation_controller.dart';
import 'package:eventor_vendor/widgets/vendor_navigation_host.dart';
import 'package:eventor_vendor/widgets/vendor_bottom_nav_bar.dart';
import 'package:eventor_vendor/widgets/vendor_page_scaffold.dart';

class _Root extends StatefulWidget {
  final bool guard;
  final VoidCallback? onBlocked;
  const _Root({this.guard = false, this.onBlocked});
  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  final nav = VendorNavigationController.instance;
  int selected = 0, created = 0;
  @override
  void initState() {
    super.initState();
    nav.attach(this, (index) {
      setState(() => selected = index);
      nav.setIndex(index);
    });
  }

  @override
  void dispose() {
    nav.detach(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => VendorPageScaffold(
    reserveNavigationSpace: true,
    extendBody: true,
    floatingActionButton: ExpandableActionButton(
      color: const Color(0xFF80152C),
      tooltip: 'Create',
      actions: [
        FloatingMenuAction(
          label: 'Add business',
          icon: Icons.store,
          onSelected: () async {
            setState(() => created++);
          },
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        key: const ValueKey('root-content'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tab $selected'),
            Text('Created $created'),
            TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    const AlertDialog(title: Text('Blocking dialog')),
              ),
              child: const Text('Open dialog'),
            ),
            Builder(
              builder: (context) => TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Check Phone Settings')),
                ),
                child: const Text('Show message'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PopScope(
                    canPop: !widget.guard,
                    onPopInvokedWithResult: (didPop, result) {
                      if (!didPop) widget.onBlocked?.call();
                    },
                    child: VendorPageScaffold(
                      appBar: AppBar(title: const Text('Detail page')),
                      body: const Column(
                        children: [
                          Expanded(
                            child: Center(child: Text('Detail content')),
                          ),
                          TextButton(
                            onPressed: null,
                            child: Text(
                              'Last action',
                              key: ValueKey('last-action'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('Open detail'),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _app({bool guard = false, VoidCallback? onBlocked}) {
  final nav = VendorNavigationController.instance;
  return MaterialApp(
    navigatorKey: nav.navigatorKey,
    navigatorObservers: [nav.observer],
    builder: (context, child) =>
        VendorNavigationHost(controller: nav, child: child!),
    home: _Root(guard: guard, onBlocked: onBlocked),
  );
}

void main() {
  testWidgets(
    'Nested SafeArea content paints behind the floating navbar without an empty strip',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      final page = tester.getRect(find.byKey(const ValueKey('root-content')));
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(page.bottom, closeTo(screenHeight, 0.1));
      expect(find.byType(VendorBottomNavBar), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Listings action menu keeps navigation visible and switches tabs safely',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Create'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 130));
      final board = find.text('Add business');
      final earlyPosition = tester.getCenter(board);
      final earlyOpacity = tester
          .widget<Opacity>(
            find.ancestor(of: board, matching: find.byType(Opacity)).first,
          )
          .opacity;
      await tester.pump(const Duration(milliseconds: 130));
      final middlePosition = tester.getCenter(board);
      final middleOpacity = tester
          .widget<Opacity>(
            find.ancestor(of: board, matching: find.byType(Opacity)).first,
          )
          .opacity;
      expect(middlePosition.dy, lessThan(earlyPosition.dy));
      expect(middleOpacity, greaterThan(earlyOpacity));
      expect(middleOpacity, lessThan(1));
      await tester.pumpAndSettle();
      expect(find.text('Add business'), findsOneWidget);
      expect(find.byType(VendorBottomNavBar), findsOneWidget);
      await tester.tap(find.text('Listings'));
      await tester.pumpAndSettle();
      expect(find.text('Add business'), findsNothing);
      expect(find.text('Tab 1'), findsOneWidget);
      expect(find.text('Created 0'), findsOneWidget);
      await tester.tap(find.byTooltip('Create'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add business'));
      await tester.pumpAndSettle();
      expect(find.text('Created 1'), findsOneWidget);
      expect(find.byType(VendorBottomNavBar), findsOneWidget);
      await tester.tap(find.byTooltip('Create'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Add business'), findsNothing);
      expect(find.byType(VendorBottomNavBar), findsOneWidget);
      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Blocking dialog'), findsOneWidget);
      expect(find.byType(VendorBottomNavBar), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Main-tab messages remain above the floating navbar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show message'));
    await tester.pumpAndSettle();
    expect(
      tester.getBottomLeft(find.byType(SnackBar)).dy,
      lessThan(tester.getTopLeft(find.byType(VendorBottomNavBar)).dy),
    );
    expect(find.byType(VendorBottomNavBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'One persistent navbar remains on details and keeps the last action visible',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byType(VendorBottomNavBar), findsOneWidget);
      await tester.tap(find.text('Open detail'));
      await tester.pumpAndSettle();
      expect(find.text('Detail page'), findsOneWidget);
      expect(find.byType(VendorBottomNavBar), findsOneWidget);
      expect(
        tester.getBottomLeft(find.byKey(const ValueKey('last-action'))).dy,
        lessThan(tester.getTopLeft(find.byType(VendorBottomNavBar)).dy),
      );
      await tester.tap(find.text('Listings'));
      await tester.pumpAndSettle();
      expect(find.text('Detail page'), findsNothing);
      expect(find.text('Tab 1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Tab changes respect the existing unsaved/in-flight page guard', (
    tester,
  ) async {
    bool blocked = false;
    await tester.pumpWidget(_app(guard: true, onBlocked: () => blocked = true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    expect(blocked, true);
    expect(find.text('Detail page'), findsOneWidget);
    expect(VendorNavigationController.instance.index, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Removing authenticated root hides navigation and closes private detail pages',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      final state = tester.state<_RootState>(find.byType(_Root));
      await tester.tap(find.text('Open detail'));
      await tester.pumpAndSettle();
      VendorNavigationController.instance.detach(state);
      await tester.pumpAndSettle();
      expect(find.byType(VendorBottomNavBar), findsNothing);
      expect(find.text('Detail page'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
