import 'package:flutter/material.dart';

import '../../widgets/customer_bottom_nav_bar.dart';

import 'customer_home_screen.dart';
import 'discover_screen.dart';
import 'bookings_screen.dart';
import 'me_screen.dart';

class CustomerMainScreen extends StatefulWidget {
  const CustomerMainScreen({
    super.key,
  });

  @override
  State<CustomerMainScreen> createState() =>
      _CustomerMainScreenState();
}

class _CustomerMainScreenState
    extends State<CustomerMainScreen> {
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

      const DiscoverScreen(),

      BookingsScreen(
        key: ValueKey<int>(
          _bookingsRefreshKey,
        ),
      ),

      const MeScreen(),
    ];

    // -------------------------------------------------------------------------
    // Main Scaffold
    // -------------------------------------------------------------------------

    return Scaffold(
      // =======================================================================
      // BODY
      // =======================================================================

      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),

      // =======================================================================
      // BOTTOM NAVIGATION
      // =======================================================================

      bottomNavigationBar: CustomerBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavigationChanged,
      ),
    );
  }
}