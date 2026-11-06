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

  // ===========================================================================
  // BOOKINGS REFRESH KEY
  // ===========================================================================

  int _bookingsRefreshKey = 0;

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  void _onNavigationChanged(int index) {
    // -------------------------------------------------------------------------
    // Same tab tapped
    // -------------------------------------------------------------------------

    if (_currentIndex == index) {
      // If Bookings is tapped again,
      // force BookingsScreen to recreate.
      if (index == 2) {
        setState(() {
          _bookingsRefreshKey++;
        });
      }

      return;
    }

    // -------------------------------------------------------------------------
    // Different tab
    // -------------------------------------------------------------------------

    setState(() {
      _currentIndex = index;

      // Whenever Bookings is opened,
      // recreate BookingsScreen.
      if (index == 2) {
        _bookingsRefreshKey++;
      }
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

      BookingsScreen(key: ValueKey<int>(_bookingsRefreshKey)),

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
            child: IndexedStack(index: _currentIndex, children: screens),
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
