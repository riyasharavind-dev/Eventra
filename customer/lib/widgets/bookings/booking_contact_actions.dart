import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class BookingContactActions extends StatefulWidget {
  const BookingContactActions({super.key, required this.bookingId});
  final String bookingId;
  @override
  State<BookingContactActions> createState() => _BookingContactActionsState();
}

class _BookingContactActionsState extends State<BookingContactActions> {
  String? phone;
  bool failed = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final value = await Supabase.instance.client.rpc(
        'customer_booking_contact',
        params: {'p_booking_id': widget.bookingId},
      );
      if (mounted) {
        setState(() {
          phone = value as String?;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  Future<void> open(bool whatsapp) async {
    var digits = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 10) digits = '91$digits';
    if (digits.length < 10 || digits.length > 15) return;
    try {
      final ok = await launchUrl(
        whatsapp
            ? Uri.https('wa.me', '/$digits')
            : Uri(scheme: 'tel', path: '+$digits'),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) throw StateError('unavailable');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppSettingsScope.translate(
                context,
                "customer.unable_to_open_this_contact_app.121cebf0",
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => failed
      ? TextButton(
          onPressed: load,
          child: Text(
            AppSettingsScope.translate(
              context,
              "customer.retry_vendor_contact.9e97b825",
            ),
          ),
        )
      : phone?.trim().isNotEmpty == true
      ? Wrap(
          spacing: 12,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF80152C),
                side: const BorderSide(color: Color(0xFFF0EDF0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => open(false),
              icon: const Icon(Icons.call_outlined, size: 18),
              label: Text(
                AppSettingsScope.translate(
                  context,
                  "customer.call_vendor.f09117de",
                ),
              ),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF80152C),
                side: const BorderSide(color: Color(0xFFF0EDF0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => open(true),
              icon: const Icon(Icons.chat_outlined, size: 18),
              label: Text(
                AppSettingsScope.translate(
                  context,
                  "customer.whatsapp.6a40edf1",
                ),
              ),
            ),
          ],
        )
      : const SizedBox.shrink();
}
