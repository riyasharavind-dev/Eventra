import 'package:flutter/material.dart';

import '../../services/app_settings_controller.dart';
import '../../widgets/trial/sample_booking_card.dart';

/// No repositories, remote images, contacts, notifications or real booking IDs.
class BookingPracticeScreen extends StatefulWidget {
  const BookingPracticeScreen({super.key});
  @override
  State<BookingPracticeScreen> createState() => _BookingPracticeScreenState();
}

class _BookingPracticeScreenState extends State<BookingPracticeScreen> {
  String _status = 'pending';
  bool _opened = false;
  String t(String en) => AppSettingsScope.source(context, en);
  Future<void> _details() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppSettingsScope.translate(
                  context,
                  "vendor.sample_booking_details.f66f31b8",
                ),
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppSettingsScope.translate(
                  context,
                  "vendor.wedding_decoration_sample_customer_10_00_am_2.7829ef27",
                ),
                style: const TextStyle(height: 1.9),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppSettingsScope.translate(
                    context,
                    "vendor.details_checked.aab8d41c",
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() => _opened = true);
  }

  Future<void> _decide(String status) async {
    if (!_opened) {
      await _details();
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          t(
            status == 'accepted'
                ? 'Accept this sample?'
                : 'Reject this sample?',
          ),
        ),
        content: Text(
          AppSettingsScope.translate(
            context,
            "vendor.practice_only_no_customer_is_notified.77e991c7",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              AppSettingsScope.translate(context, "vendor.cancel.19766ed6"),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppSettingsScope.translate(context, "vendor.confirm.eebdd24a"),
            ),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        AppSettingsScope.translate(context, "vendor.booking_practice.9f0132a0"),
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            AppSettingsScope.translate(
              context,
              "vendor.practice_mode_sample_data.661e9e03",
            ),
            style: const TextStyle(
              color: Color(0xFF80152C),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            t(
              _opened
                  ? 'Now try Accept or Reject. In the real app, only accept work you can fulfil.'
                  : 'Tap the card arrow and review the details first.',
            ),
            style: const TextStyle(height: 1.5),
          ),
          const SizedBox(height: 20),
          SampleBookingCard(
            status: _status,
            onOpen: _details,
            onAccept: () => _decide('accepted'),
            onReject: () => _decide('rejected'),
            onComplete: () => setState(() => _status = 'completed'),
          ),
          if (_status != 'pending') ...[
            const SizedBox(height: 12),
            Text(
              AppSettingsScope.translate(
                context,
                "vendor.nice_the_sample_status_changed_real_booking_a.156fa0bc",
              ),
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const ValueKey('practice-done'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                AppSettingsScope.translate(
                  context,
                  "vendor.practice_complete.7093ddd7",
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _status = 'pending';
                _opened = false;
              }),
              child: Text(
                AppSettingsScope.translate(
                  context,
                  "vendor.try_again.d8b8392e",
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
