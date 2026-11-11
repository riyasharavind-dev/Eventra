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
  final bool reserveNavigationSpace;
  const VendorPageScaffold({
    super.key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset,
    this.reserveNavigationSpace = false,
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
            (detail || reserveNavigationSpace) &&
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
          // Scaffold.extendBody adds the reserved navigation height to the
          // body's MediaQuery padding. Nested main-tab SafeAreas would consume
          // that padding and leave a solid empty strip behind the floating bar.
          // Keep the reservation for snackbars/FABs, but let page content paint
          // through it using only the device's actual bottom safe area.
          // Keep the element tree stable when the keyboard hides the nav.
          // Switching between wrapped/raw body here remounts every tab.
          body: body == null
              ? null
              : Builder(
                  builder: (innerContext) {
                    final data = MediaQuery.of(innerContext);
                    return MediaQuery(
                      data: extendBody && space > 0
                          ? data.copyWith(
                              padding: data.padding.copyWith(
                                bottom: MediaQuery.paddingOf(context).bottom,
                              ),
                            )
                          : data,
                      child: body!,
                    );
                  },
                ),
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
