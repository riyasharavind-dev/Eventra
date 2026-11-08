import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eventor_vendor/models/app_settings_model.dart';
import 'package:eventor_vendor/models/vendor_tour_step.dart';
import 'package:eventor_vendor/repositories/onboarding_repository.dart';
import 'package:eventor_vendor/screens/onboarding/onboarding_screen.dart';
import 'package:eventor_vendor/screens/trial/vendor_trial_screen.dart';
import 'package:eventor_vendor/screens/trial/booking_practice_screen.dart';
import 'package:eventor_vendor/services/app_settings_controller.dart';
import 'package:eventor_vendor/widgets/trial/vendor_setup_checklist.dart';

class MemoryGuide extends OnboardingRepository {
  VendorGuideProgress progress = const VendorGuideProgress();
  VendorSetupChecklist checklist = const VendorSetupChecklist(
    profileComplete: false,
    businessCount: 0,
    serviceCount: 0,
  );
  final writes = <VendorGuideProgress>[];
  bool restarted = false;
  @override
  Future<VendorGuideProgress> loadProgress() async => progress;
  @override
  Future<bool> saveProgress(
    VendorGuideProgress value, {
    bool restart = false,
  }) async {
    progress = value;
    writes.add(value);
    restarted = restarted || restart;
    return true;
  }

  @override
  Future<VendorSetupChecklist> loadChecklist() async => checklist;
}

void main() {
  late AppSettingsController settings;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    settings = AppSettingsController(initial: const AppSettingsModel());
  });
  tearDown(() => settings.dispose());
  Widget app(Widget child) => AppSettingsScope(
    controller: settings,
    child: MaterialApp(home: child),
  );
  Future<void> tap(WidgetTester tester, String text) async {
    final target = find.text(text).last;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'introduction completes once per install and skip also persists',
    (tester) async {
      final repository = OnboardingRepository();
      await tester.pumpWidget(
        app(
          VendorOnboardingGate(
            repository: repository,
            child: const Scaffold(body: Text('Login destination')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Welcome to Eventor'), findsOneWidget);
      await tap(tester, 'Next');
      await tap(tester, 'Next');
      await tap(tester, 'Get Started');
      expect(find.text('Login destination'), findsOneWidget);
      expect(await repository.needsIntroduction(), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        app(
          VendorOnboardingGate(
            repository: repository,
            child: const Scaffold(body: Text('Login destination')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Welcome to Eventor'), findsNothing);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        app(
          VendorOnboardingGate(
            repository: repository,
            child: const Scaffold(body: Text('Login destination')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, 'Skip');
      expect(await repository.needsIntroduction(), isFalse);
    },
  );
  testWidgets(
    'six interactive steps and sample accept complete without any booking repository',
    (tester) async {
      final repository = MemoryGuide();
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    VendorTrialScreen.open(context, repository: repository),
                child: const Text('Open tour'),
              ),
            ),
          ),
        ),
      );
      await tap(tester, 'Open tour');
      await tap(tester, 'Listings');
      await tester.ensureVisible(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tap(tester, 'Add a business');
      await tap(tester, 'Save sample only');
      await tap(tester, 'Open sample booking');
      expect(find.byType(BookingPracticeScreen), findsOneWidget);
      await tap(tester, 'Wedding decoration • Sample');
      await tap(tester, 'Details checked');
      await tap(tester, 'Accept');
      await tap(tester, 'Confirm');
      await tap(tester, 'Practice complete');
      await tap(tester, 'App Settings');
      await tap(tester, 'Got it');
      expect(repository.progress.status, 'completed');
      expect(repository.progress.step, 6);
      await tap(tester, 'Start using Eventor');
      expect(find.text('Open tour'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('sample reject and try-again reset only local practice', (
    tester,
  ) async {
    await tester.pumpWidget(app(const BookingPracticeScreen()));
    await tester.pumpAndSettle();
    await tap(tester, 'Wedding decoration • Sample');
    await tap(tester, 'Details checked');
    await tap(tester, 'Reject');
    await tap(tester, 'Confirm');
    expect(find.text('Practice complete'), findsOneWidget);
    await tap(tester, 'Try again');
    expect(find.text('Practice complete'), findsNothing);
    expect(find.text('Accept'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('resume, skip and explicit restart preserve the intended step', (
    tester,
  ) async {
    final repository = MemoryGuide()
      ..progress = const VendorGuideProgress(status: 'in_progress', step: 4);
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () =>
                      VendorTrialScreen.open(context, repository: repository),
                  child: const Text('Resume'),
                ),
                TextButton(
                  onPressed: () => VendorTrialScreen.open(
                    context,
                    repository: repository,
                    restart: true,
                  ),
                  child: const Text('Replay'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tap(tester, 'Resume');
    expect(find.text('Step 5 of 6'), findsOneWidget);
    await tester.tap(find.byTooltip('Skip tour'));
    await tester.pumpAndSettle();
    expect(repository.progress.status, 'skipped');
    expect(repository.progress.step, 4);
    await tap(tester, 'Replay');
    expect(find.text('Step 1 of 6'), findsOneWidget);
    expect(repository.restarted, isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Resume'), findsOneWidget);
  });
  testWidgets('checklist hides only when actual setup is complete', (
    tester,
  ) async {
    final repository = MemoryGuide()
      ..progress = const VendorGuideProgress(status: 'completed', step: 6);
    await tester.pumpWidget(
      app(Scaffold(body: VendorSetupChecklistCard(repository: repository))),
    );
    await tester.pumpAndSettle();
    expect(find.text('0 of 3 complete'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    repository.checklist = const VendorSetupChecklist(
      profileComplete: true,
      businessCount: 1,
      serviceCount: 1,
    );
    await tester.pumpWidget(
      app(Scaffold(body: VendorSetupChecklistCard(repository: repository))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Set up your account'), findsNothing);
  });
  testWidgets(
    'Tamil onboarding and practice form fit a narrow screen at large text scale',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      settings.dispose();
      settings = AppSettingsController(
        initial: const AppSettingsModel(languageCode: 'ta'),
      );
      Widget scaled(Widget child) => app(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 700),
            textScaler: TextScaler.linear(1.5),
          ),
          child: child,
        ),
      );
      await tester.pumpWidget(scaled(OnboardingScreen(onFinished: () {})));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final repository = MemoryGuide()
        ..progress = const VendorGuideProgress(status: 'in_progress', step: 3);
      await tester.pumpWidget(
        scaled(VendorTrialScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('மாதிரியை மட்டும் சேமி'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
