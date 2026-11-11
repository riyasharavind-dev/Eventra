import 'package:eventor_customer/services/app_settings_controller.dart';

import '../../services/app_live_data.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/customer_bottom_nav_bar.dart';

import 'customer_home_screen.dart';
import 'explore_screen.dart';
import 'bookings_screen.dart';
import 'me_screen.dart';

class CustomerMainScreen extends StatefulWidget {
  const CustomerMainScreen({super.key, this.accountId});
  final String? accountId;

  @override
  State<CustomerMainScreen> createState() => _CustomerMainScreenState();
}

class _CustomerMainScreenState extends State<CustomerMainScreen> {
  // ===========================================================================
  // CURRENT TAB
  // ===========================================================================

  int _currentIndex = 0;
  DateTime? _lastBack;
  final _visited = <int>{0};

  @override
  void didUpdateWidget(covariant CustomerMainScreen old) {
    super.didUpdateWidget(old);
    if (old.accountId != widget.accountId) {
      _visited.removeAll({2, 3});
      if (widget.accountId == null) {
        _currentIndex = 0;
        _visited
          ..clear()
          ..add(0);
      } else {
        _visited.add(_currentIndex);
      }
    }
  }
  // ===========================================================================
  // BOOKINGS REFRESH KEY
  // ===========================================================================

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  Future<void> _onNavigationChanged(int index) async {
    if (!mounted) return;
    if (index < 0 || index > 3) return;
    if (_currentIndex == index) {
      if (index == 2) AppLiveData.instance.invalidate({'own:bookings'});
      return;
    }
    setState(() {
      _currentIndex = index;
      _visited.add(index);
    });
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    // -------------------------------------------------------------------------
    // Screens
    // -------------------------------------------------------------------------

    final List<Widget> screens = [
      CustomerHomeScreen(key: ValueKey('home-${widget.accountId ?? 'guest'}')),

      const ExploreScreen(),

      const BookingsScreen(),

      const MeScreen(),
    ];

    // -------------------------------------------------------------------------
    // Main Scaffold
    // -------------------------------------------------------------------------

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex != 0) {
          _onNavigationChanged(0);
          _lastBack = null;
          return;
        }
        final now = DateTime.now();
        if (_lastBack != null &&
            now.difference(_lastBack!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBack = now;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.fromLTRB(16, 0, 16, 110),
            duration: Duration(seconds: 2),
            content: Text(
              AppSettingsScope.translate(
                context,
                "customer.press_back_again_to_exit.c151b888",
              ),
            ),
          ),
        );
      },
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  for (var i = 0; i < screens.length; i++)
                    _visited.contains(i)
                        ? TickerMode(
                            enabled: i == _currentIndex,
                            child: screens[i],
                          )
                        : const SizedBox.shrink(),
                ],
              ),
            ),
            if (MediaQuery.viewInsetsOf(context).bottom == 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: CustomerBottomNavBar(
                  currentIndex: _currentIndex,
                  onTap: _onNavigationChanged,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
