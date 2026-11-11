import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:flutter/material.dart';

import '../../repositories/booking_repository.dart';
import '../../services/app_live_data.dart';

class CompletionConfirmationButton extends StatefulWidget {
  const CompletionConfirmationButton({
    super.key,
    required this.bookingId,
    this.repository,
    this.onConfirmed,
  });
  final String bookingId;
  final BookingRepository? repository;
  final VoidCallback? onConfirmed;
  @override
  State<CompletionConfirmationButton> createState() =>
      _CompletionConfirmationState();
}

class _CompletionConfirmationState extends State<CompletionConfirmationButton> {
  bool busy = false;
  Future<void> confirm() async {
    if (busy) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          AppSettingsScope.translate(
            context,
            "customer.confirm_event_completion.0c51c255",
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Color(0xFF17171B),
          ),
        ),
        content: Text(
          AppSettingsScope.translate(
            context,
            "customer.the_vendor_marked_this_event_as_finished_conf.d3d1eec3",
          ),
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Color(0xFF73737D),
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF73737D),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppSettingsScope.translate(context, "customer.not_yet.a9549d7d"),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF80152C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppSettingsScope.translate(
                context,
                "customer.yes_completed.5f763d6a",
              ),
            ),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => busy = true);
    try {
      await (widget.repository ?? BookingRepository()).acknowledgeCompletion(
        widget.bookingId,
      );
      AppLiveData.instance.invalidate({
        'own:bookings',
        'own:booking_status_history',
      });
      widget.onConfirmed?.call();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppSettingsScope.translate(
                context,
                "customer.unable_to_confirm_refresh_the_booking_and_try.e7439770",
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : confirm,
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF80152C),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0,
    ),
    child: Text(
      busy ? 'Confirming…' : 'Confirm Completion',
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}
