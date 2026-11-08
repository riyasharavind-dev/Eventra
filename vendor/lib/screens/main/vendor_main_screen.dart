import '../../services/app_live_data.dart';
import '../../repositories/onboarding_repository.dart';
import '../../models/vendor_tour_step.dart';
import '../../services/app_settings_controller.dart';
import '../trial/vendor_trial_screen.dart';
import '../../widgets/vendor_page_scaffold.dart';
import '../../widgets/common/main_screen_back_guard.dart';

import 'package:flutter/material.dart';

import '../../services/vendor_navigation_controller.dart';
import 'dashboard_screen.dart';
import 'listings_screen.dart';
import 'bookings_screen.dart';
import 'me_screen.dart';

class VendorMainScreen extends StatefulWidget {
  const VendorMainScreen({super.key});

  @override
  State<VendorMainScreen> createState() => _VendorMainScreenState();
}

class _VendorMainScreenState extends State<VendorMainScreen>
    with LiveDataState<VendorMainScreen> {
  @override
  Set<String> get liveDatasets => {'own:vendor_guide_progress'};
  @override
  Future<void> onLiveData(Set<String> changed) async {
    // Reconnect/resume catches up any learning progress saved offline.
    await OnboardingRepository().loadProgress();
  }

  int _currentIndex = 0;
  final _visited = <int>{0};
  @override
  void initState() {
    super.initState();
    VendorNavigationController.instance.attach(this, _onNavigationChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerGuide());
  }

  Future<void> _offerGuide() async {
    final repository = OnboardingRepository();
    try {
      final progress = await repository.loadProgress();
      if (!mounted ||
          !progress.shouldOffer ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      final settings = AppSettingsScope.of(context);
      String t(String en, String ta) => settings.text(en, ta);
      final start = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t('A quick tour?', 'ஒரு சிறிய அறிமுகம்?')),
          content: Text(
            t(
              'Learn where to tap and practice a sample booking. About 1 minute, with no real changes.',
              'எதைத் தொடுவது என்று அறிந்து, மாதிரி முன்பதிவில் பயிற்சி செய்யுங்கள். சுமார் 1 நிமிடம்; உண்மையான மாற்றங்கள் இல்லை.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t('Later', 'பிறகு')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                t(
                  progress.step > 0 ? 'Resume tour' : 'Start tour',
                  progress.step > 0
                      ? 'பயிற்சியைத் தொடரவும்'
                      : 'பயிற்சியைத் தொடங்கு',
                ),
              ),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (start == true) {
        await VendorTrialScreen.open(
          context,
          repository: repository,
          initialProgress: progress,
        );
      } else {
        await repository.saveProgress(
          VendorGuideProgress(status: 'skipped', step: progress.step),
        );
      }
    } catch (_) {
      // A learning prompt must never block sign-in or the actual dashboard.
    }
  }

  @override
  void dispose() {
    VendorNavigationController.instance.detach(this);
    super.dispose();
  }

  List<Widget> get _screens => [
    DashboardScreen(
      isActive: _currentIndex == 0,
      onNavigate: _onNavigationChanged,
    ),
    const ListingsScreen(),
    const BookingsScreen(),
    MeScreen(
      isActive: _currentIndex == 3,
      onBookings: () => _onNavigationChanged(2),
    ),
  ];

  void _onNavigationChanged(int index) {
    if (index < 0 || index >= _screens.length) return;

    setState(() {
      _currentIndex = index;
      _visited.add(index);
      VendorNavigationController.instance.setIndex(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MainScreenBackGuard(
      currentIndex: _currentIndex,
      onDashboard: () => _onNavigationChanged(0),
      child: VendorPageScaffold(
        reserveNavigationSpace: true,
        extendBody: true,
        backgroundColor: const Color(0xFFF8F8FA),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            for (var i = 0; i < 4; i++)
              _visited.contains(i)
                  ? TickerMode(enabled: i == _currentIndex, child: _screens[i])
                  : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
