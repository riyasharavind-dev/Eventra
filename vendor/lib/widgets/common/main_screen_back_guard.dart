import 'package:eventor_vendor/services/app_settings_controller.dart';

import '../../services/vendor_tour_controller.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Main tabs return home before requiring a second back press to exit.
class MainScreenBackGuard extends StatefulWidget {
  const MainScreenBackGuard({
    super.key,
    required this.currentIndex,
    required this.onDashboard,
    required this.child,
  });
  final int currentIndex;
  final VoidCallback onDashboard;
  final Widget child;
  @override
  State<MainScreenBackGuard> createState() => _MainScreenBackGuardState();
}

class _MainScreenBackGuardState extends State<MainScreenBackGuard> {
  Timer? _exitWindow;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _message;

  void _reset({bool deferMessage = false}) {
    _exitWindow?.cancel();
    _exitWindow = null;
    if (_message != null) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (deferMessage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _message == null) messenger?.removeCurrentSnackBar();
        });
      } else {
        messenger?.removeCurrentSnackBar();
      }
    }
    _message = null;
  }

  @override
  void didUpdateWidget(covariant MainScreenBackGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _reset(deferMessage: true);
    }
  }

  @override
  void dispose() {
    _exitWindow?.cancel();
    super.dispose();
  }

  void _onBack(bool didPop, Object? result) {
    if (didPop) return;
    if (VendorTourController.instance.active) {
      _reset();
      unawaited(VendorTourController.instance.back());
      return;
    }
    if (widget.currentIndex != 0) {
      _reset();
      widget.onDashboard();
      return;
    }
    if (_exitWindow?.isActive ?? false) {
      _reset();
      SystemNavigator.pop();
      return;
    }

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    _message = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        content: Text(
          AppSettingsScope.translate(
            context,
            "vendor.press_back_again_to_exit.c151b888",
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
    final message = _message;
    message?.closed.then((_) {
      if (identical(_message, message)) _message = null;
    });
    _exitWindow = Timer(const Duration(seconds: 3), () {
      _exitWindow = null;
    });
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: false,
    onPopInvokedWithResult: _onBack,
    child: widget.child,
  );
}
