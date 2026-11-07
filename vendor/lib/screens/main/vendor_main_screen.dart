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

class _VendorMainScreenState extends State<VendorMainScreen> {
  int _currentIndex = 0;
  @override
  void initState() {
    super.initState();
    VendorNavigationController.instance.attach(this, _onNavigationChanged);
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
      VendorNavigationController.instance.setIndex(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MainScreenBackGuard(
      currentIndex: _currentIndex,
      onDashboard: () => _onNavigationChanged(0),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F8FA),
        body: IndexedStack(index: _currentIndex, children: _screens),
      ),
    );
  }
}
