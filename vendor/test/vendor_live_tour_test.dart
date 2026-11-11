import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eventor_vendor/models/app_settings_model.dart';
import 'package:eventor_vendor/models/vendor_tour_step.dart';
import 'package:eventor_vendor/repositories/onboarding_repository.dart';
import 'package:eventor_vendor/services/app_settings_controller.dart';
import 'package:eventor_vendor/services/vendor_navigation_controller.dart';
import 'package:eventor_vendor/services/vendor_tour_controller.dart';
import 'package:eventor_vendor/widgets/vendor_navigation_host.dart';
import 'package:eventor_vendor/widgets/common/expandable_action_button.dart';
import 'package:eventor_vendor/widgets/trial/tour_anchor.dart';
import 'package:eventor_vendor/widgets/trial/tour_instruction_card.dart';

class GuideStore extends OnboardingRepository {
  String owner = 'vendor-a';
  VendorGuideProgress state = const VendorGuideProgress();
  final writes = <VendorGuideProgress>[];
  @override
  String? get accountId => owner;
  @override
  Future<VendorGuideProgress> loadProgress() async => state;
  @override
  Future<bool> saveProgress(
    VendorGuideProgress value, {
    bool restart = false,
  }) async {
    state = value;
    writes.add(value);
    return true;
  }
}

class RealControlHarness extends StatefulWidget {
  const RealControlHarness({super.key});
  @override
  State<RealControlHarness> createState() => HarnessState();
}

class HarnessState extends State<RealControlHarness> {
  int tab = 0, opened = 0, calendarTaps = 0, saves = 0, languageChanges = 0;
  final nav = VendorNavigationController.instance;
  final tour = VendorTourController.instance;
  @override
  void initState() {
    super.initState();
    nav.attach(this, (i) {
      setState(() => tab = i);
      nav.setIndex(i);
    });
  }

  @override
  void dispose() {
    nav.detach(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Text('Actual tab $tab'),
          if (tab == 1)
            const Expanded(child: Center(child: Text('Actual listings'))),
          if (tab == 2)
            TourAnchor(
              id: TourTargets.calendar,
              child: IconButton(
                tooltip: 'Actual calendar',
                icon: const Icon(Icons.calendar_month),
                onPressed: () {
                  tour.calendarOpenedNow();
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(
                          title: const Text('Actual calendar screen'),
                        ),
                        body: TourAnchor(
                          id: TourTargets.dates,
                          child: TextButton(
                            onPressed: () => setState(() => calendarTaps++),
                            child: const Text('Actual date 14'),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (tab == 3)
            TourAnchor(
              id: TourTargets.language,
              child: ListTile(
                title: const Text('Actual Language'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(
                          title: const Text('Actual language screen'),
                        ),
                        body: TourAnchor(
                          id: TourTargets.languages,
                          child: TextButton(
                            onPressed: () => setState(() => languageChanges++),
                            child: const Text('Actual Tamil option'),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    ),
    floatingActionButton: tab == 1
        ? Padding(
            padding: const EdgeInsets.only(bottom: 110),
            child: ExpandableActionButton(
              color: const Color(0xFF80152C),
              tooltip: 'Actual add',
              actions: [
                FloatingMenuAction(
                  label: 'Actual Add a business',
                  icon: Icons.storefront,
                  tourId: TourTargets.business,
                  onSelected: () async {
                    tour.businessOpened();
                    opened++;
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: AppBar(
                            title: const Text('Actual business form'),
                          ),
                          body: Column(
                            children: [
                              TourAnchor(
                                id: TourTargets.category,
                                child: DropdownButtonFormField<String>(
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'decoration',
                                      child: Text('Decoration'),
                                    ),
                                  ],
                                  onChanged: (_) {},
                                ),
                              ),
                              TextButton(
                                key: const ValueKey('real-save'),
                                onPressed: () => saves++,
                                child: const Text('Actual Save business'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          )
        : null,
  );
}

void main() {
  late AppSettingsController settings;
  late GuideStore store;
  final tour = VendorTourController.instance;
  final nav = VendorNavigationController.instance;
  final harness = GlobalKey<HarnessState>();
  setUp(() {
    settings = AppSettingsController(initial: const AppSettingsModel());
    store = GuideStore();
  });
  tearDown(() {
    tour.cancel(save: false);
    settings.dispose();
  });
  Future<void> page(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      AppSettingsScope(
        controller: settings,
        child: MaterialApp(
          navigatorKey: nav.navigatorKey,
          navigatorObservers: [nav.observer],
          builder: (context, child) =>
              VendorNavigationHost(controller: nav, child: child!),
          home: RealControlHarness(key: harness),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tour.start(repository: store, restart: true);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'spotlight taps original navigation and animated add-menu controls; no automatic save',
    (tester) async {
      await page(tester);
      expect(find.byType(TourMiniTipCard), findsOneWidget);
      await tester.tap(find.text('Listings'));
      await settle(tester);
      expect(tour.step, 1);
      expect(harness.currentState!.tab, 1);
      await tester.tap(find.byTooltip('Actual add'));
      await settle(tester);
      expect(tour.step, 2);
      await tester.tap(find.text('Actual Add a business'));
      await settle(tester);
      expect(tour.step, 3);
      expect(harness.currentState!.opened, 1);
      expect(find.text('Actual business form'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('real-save')),
        warnIfMissed: false,
      );
      await settle(tester);
      expect(harness.currentState!.saves, 0);
      await tester.tap(find.widgetWithText(FilledButton, 'Bookings'));
      await settle(tester);
      expect(harness.currentState!.tab, 2);
      expect(tour.step, 4);
      await tester.tap(find.byTooltip('Actual calendar'));
      await settle(tester);
      expect(find.text('Actual calendar screen'), findsOneWidget);
      await tester.tap(find.text('Actual date 14'));
      await settle(tester);
      expect(harness.currentState!.calendarTaps, 1);
      await tester.tap(find.widgetWithText(FilledButton, 'Me'));
      await settle(tester);
      expect(harness.currentState!.tab, 3);
      expect(tour.step, 5);
      await tester.tap(find.text('Actual Language'));
      await settle(tester);
      expect(find.text('Actual language screen'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
      await settle(tester);
      expect(tour.active, isFalse);
      expect(store.state.status, 'completed');
      expect(store.state.step, 6);
      expect(harness.currentState!.languageChanges, 0);
      expect(harness.currentState!.saves, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'skip leaves the app interactive and a changed account cannot inherit the overlay',
    (tester) async {
      await page(tester);
      await tester.tap(find.byTooltip('Skip tour'));
      await settle(tester);
      expect(tour.active, isFalse);
      expect(store.state.status, 'skipped');
      await tour.start(repository: store, restart: true);
      await settle(tester);
      store.owner = 'vendor-b';
      await tester.pump(const Duration(milliseconds: 180));
      await tester.pumpAndSettle();
      expect(tour.active, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
  testWidgets('mini tips wrap on a narrow screen at large Tamil text scale', (
    tester,
  ) async {
    settings.dispose();
    settings = AppSettingsController(
      initial: const AppSettingsModel(languageCode: 'ta'),
    );
    await page(tester);
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await settle(tester);
    expect(tester.takeException(), isNull);
    tour.cancel(save: false);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
