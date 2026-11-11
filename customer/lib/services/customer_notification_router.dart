import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/booking_repository.dart';
import '../repositories/auth_repository.dart';
import '../screens/extended/booking_details_screen.dart';
import 'app_live_data.dart';

class CustomerNotificationRouter {
  static final navigatorKey = GlobalKey<NavigatorState>();
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();
  static bool opening = false;
  static final Map<String, DateTime> _seen = {};
  static Future<void> open(Map<String, dynamic> data) async {
    final id = data['booking_id']?.toString();
    final user = Supabase.instance.client.auth.currentUser?.id;
    if (id == null ||
        !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id) ||
        user == null ||
        opening) {
      return;
    }
    final event = data['event_id']?.toString();
    if (event != null &&
        _seen[event] != null &&
        DateTime.now().difference(_seen[event]!) < const Duration(seconds: 3)) {
      return;
    }
    opening = true;
    try {
      await AuthRepository().validateAccountRole();
      final booking = await BookingRepository().getBookingById(id);
      if (booking == null ||
          Supabase.instance.client.auth.currentUser?.id != user) {
        return;
      }
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;
      if (event != null) {
        _seen[event] = DateTime.now();
        if (_seen.length > 100) _seen.remove(_seen.keys.first);
      }
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => BookingDetailsScreen(booking: booking),
        ),
      );
    } catch (_) {
      messengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open this booking. Check Bookings and try again.',
          ),
        ),
      );
    } finally {
      opening = false;
    }
  }

  static void foreground(
    Map<String, dynamic> data,
    String? title,
    String? body,
  ) {
    AppLiveData.instance.invalidate({'own:bookings'});
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          110 +
              (navigatorKey.currentContext == null
                  ? 0
                  : MediaQuery.viewPaddingOf(navigatorKey.currentContext!)
                        .bottom),
        ),
        content: Text([title, body].whereType<String>().join('\n')),
        action: SnackBarAction(label: 'View', onPressed: () => open(data)),
      ),
    );
  }
}
