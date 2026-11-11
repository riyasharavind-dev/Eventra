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

      String t(String en) => AppSettingsScope.source(context, en);
      final start = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            AppSettingsScope.translate(context, "vendor.a_quick_tour.aeb88d6c"),
          ),
          content: Text(
            AppSettingsScope.translate(
              context,
              "vendor.follow_the_real_buttons_and_screens_with_quic.9f4d1491",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                AppSettingsScope.translate(context, "vendor.later.73b6e48a"),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t(progress.step > 0 ? 'Resume tour' : 'Start tour')),
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
