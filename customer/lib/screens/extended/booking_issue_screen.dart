import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/support_repository.dart';
import 'support_request_detail_screen.dart';

class BookingIssueScreen extends StatefulWidget {
  const BookingIssueScreen({super.key, required this.bookingId});
  final String bookingId;
  @override
  State<BookingIssueScreen> createState() => _BookingIssueState();
}

class _BookingIssueState extends State<BookingIssueScreen> {
  final text = TextEditingController();
  final repo = SupportRepository();
  late final id = repo.newRequestId();
  bool busy = false;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (busy || text.text.trim().length < 10) return;
    setState(() => busy = true);
    try {
      await Supabase.instance.client.rpc(
        'customer_booking_issue',
        params: {
          'p_booking_id': widget.bookingId,
          'p_request_id': id,
          'p_description': text.text.trim(),
        },
      );
      final ticket = (await repo.getTickets(ticketId: id)).single;
      if (mounted) {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SupportRequestDetailScreen(ticket: ticket, repository: repo),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppSettingsScope.translate(
                context,
                "customer.unable_to_send_please_retry.3e469663",
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F8FA),
    appBar: AppBar(
      centerTitle: true,
      title: Text(
        AppSettingsScope.translate(context, "customer.booking_issue.ab70f6bd"),
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: Color(0xFF17171B),
        ),
      ),
      backgroundColor: const Color(0xFFF8F8FA),
      elevation: 0,
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF0EDF0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF80152C).withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5E8EC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.report_problem_outlined,
                      color: Color(0xFF80152C),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppSettingsScope.translate(
                        context,
                        "customer.booking_value0.b3943977",
                        args: {"value0": widget.bookingId},
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF17171B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: text,
                minLines: 4,
                maxLines: 8,
                maxLength: 5000,
                decoration: InputDecoration(
                  labelText: AppSettingsScope.translate(
                    context,
                    "customer.describe_the_issue.e708aa6b",
                  ),
                  helperText: AppSettingsScope.translate(
                    context,
                    "customer.at_least_10_characters.4a33faf8",
                  ),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF80152C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  onPressed: busy ? null : send,
                  child: Text(busy ? 'Sending…' : 'Send to Support'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
