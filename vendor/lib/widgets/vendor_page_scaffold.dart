import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/vendor_navigation_controller.dart';

/// Detail pages paint their own background behind the shared floating nav while
/// keeping their content and action buttons above it.
class VendorPageScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body, floatingActionButton, bottomNavigationBar;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;
  final bool extendBody, extendBodyBehindAppBar;
  const VendorPageScaffold({
    super.key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
  });
  @override
  Widget build(BuildContext context) {
    final controller = VendorNavigationController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final detail = ModalRoute.of(context)?.isFirst == false;
        final space =
            detail &&
                controller.active &&
                MediaQuery.viewInsetsOf(context).bottom == 0
            ? 100.0 + math.max(8.0, MediaQuery.paddingOf(context).bottom)
            : 0.0;
        return Scaffold(
          appBar: appBar,
          backgroundColor: backgroundColor,
          resizeToAvoidBottomInset: resizeToAvoidBottomInset,
          extendBody: extendBody,
          extendBodyBehindAppBar: extendBodyBehindAppBar,
          body: body,
          floatingActionButton: floatingActionButton,
          floatingActionButtonLocation: floatingActionButtonLocation,
          bottomNavigationBar: space > 0
              ? Padding(
                  padding: EdgeInsets.only(bottom: space),
                  child: bottomNavigationBar ?? const SizedBox.shrink(),
                )
              : bottomNavigationBar,
        );
      },
    );
  }
}
