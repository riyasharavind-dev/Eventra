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
  int selected = 0;
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
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Tab $selected'),
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
                        Expanded(child: Center(child: Text('Detail content'))),
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
