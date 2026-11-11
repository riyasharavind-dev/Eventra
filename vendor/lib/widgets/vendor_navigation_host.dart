import 'trial/tour_overlay.dart';
import '../services/vendor_tour_controller.dart';

import 'package:flutter/material.dart';

import '../services/vendor_navigation_controller.dart';
import 'vendor_bottom_nav_bar.dart';

class VendorNavigationHost extends StatefulWidget {
  final Widget child;
  final VendorNavigationController controller;
  const VendorNavigationHost({
    super.key,
    required this.child,
    required this.controller,
  });
  @override
  State<VendorNavigationHost> createState() => _VendorNavigationHostState();
}

class _VendorNavigationHostState extends State<VendorNavigationHost> {
  late final OverlayEntry _entry = OverlayEntry(builder: _content);
  @override
  void didUpdateWidget(VendorNavigationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    _entry.remove();
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);

  Widget _content(BuildContext context) {
    final controller = widget.controller;
    return AnimatedBuilder(
      animation: controller,
      child: widget.child,
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
                onTap: (index) async {
                  await controller.select(index);
                  VendorTourController.instance.tabSelected(controller.index);
                },
              ),
            ),
          const VendorTourLayer(),
        ],
      ),
    );
  }
}
