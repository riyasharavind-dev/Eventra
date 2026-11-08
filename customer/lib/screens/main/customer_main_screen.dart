import '../../services/app_live_data.dart';

import 'package:flutter/material.dart';

import '../../widgets/customer_bottom_nav_bar.dart';

import 'customer_home_screen.dart';
import 'explore_screen.dart';
import 'bookings_screen.dart';
import 'me_screen.dart';

class CustomerMainScreen extends StatefulWidget {
  const CustomerMainScreen({super.key});

  @override
  State<CustomerMainScreen> createState() => _CustomerMainScreenState();
}

class _CustomerMainScreenState extends State<CustomerMainScreen> {
  // ===========================================================================
  // CURRENT TAB
  // ===========================================================================

  int _currentIndex = 0;
  final _visited = <int>{0};

  // ===========================================================================
  // BOOKINGS REFRESH KEY
  // ===========================================================================

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  void _onNavigationChanged(int index) {
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
      const CustomerHomeScreen(),

      const ExploreScreen(),

      const BookingsScreen(),

      const MeScreen(),
    ];

    // -------------------------------------------------------------------------
    // Main Scaffold
    // -------------------------------------------------------------------------

    return Scaffold(
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
    );
  }
}
