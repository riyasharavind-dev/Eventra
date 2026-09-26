import 'package:flutter/material.dart';

import '../../widgets/vendor_bottom_nav_bar.dart';
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

  final List<Widget> _screens = const [
    DashboardScreen(),
    ListingsScreen(),
    BookingsScreen(),
    MeScreen(),
  ];

  void _onNavigationChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: VendorBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavigationChanged,
      ),
    );
  }
}