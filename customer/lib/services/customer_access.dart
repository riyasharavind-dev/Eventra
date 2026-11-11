import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/auth/customer_auth_screen.dart';
import '../widgets/auth/login_required_dialog.dart';

class CustomerAccess {
  static bool _active = false;
  static bool get signedIn {
    try {
      return Supabase.instance.client.auth.currentSession != null;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requireSignIn(
    BuildContext context, {
    bool Function()? authenticated,
    Widget Function(bool)? authBuilder,
  }) async {
    final check = authenticated ?? () => signedIn;
    if (check()) return true;
    if (_active) return false;
    _active = true;
    try {
      final choice = await showDialog<CustomerLoginChoice>(
        context: context,
        builder: (_) => BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: const CustomerLoginDialog(),
        ),
      );
      if (choice == null || !context.mounted) return false;
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              authBuilder?.call(choice == CustomerLoginChoice.signup) ??
              CustomerAuthScreen(signup: choice == CustomerLoginChoice.signup),
        ),
      );
      return result == true && check();
    } finally {
      _active = false;
    }
  }

  static Future<void> open(BuildContext context, Widget screen) async {
    if (!await requireSignIn(context) || !context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }
}
