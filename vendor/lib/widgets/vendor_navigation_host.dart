import 'package:flutter/material.dart';

import '../services/vendor_navigation_controller.dart';
import 'vendor_bottom_nav_bar.dart';

class VendorNavigationHost extends StatelessWidget {
  final Widget child;
  final VendorNavigationController controller;
  const VendorNavigationHost({
    super.key,
    required this.child,
    required this.controller,
  });
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: child,
    builder: (context, content) => Stack(
      fit: StackFit.expand,
      children: [
        content!,
        if (controller.active &&
            !controller.modalOpen &&
            MediaQuery.viewInsetsOf(context).bottom == 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VendorBottomNavBar(
              currentIndex: controller.index,
              onTap: controller.select,
            ),
          ),
      ],
    ),
  );
}
