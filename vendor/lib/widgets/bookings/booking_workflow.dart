import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/booking_model.dart';
import '../../services/app_live_data.dart';

class BookingWorkflow extends StatefulWidget {
  const BookingWorkflow({
    super.key,
    required this.booking,
    required this.onChanged,
    this.vendor = false,
  });
  final BookingModel booking;
  final Future<void> Function() onChanged;
  final bool vendor;
  @override
  State<BookingWorkflow> createState() => _BookingWorkflowState();
}

class _BookingWorkflowState extends State<BookingWorkflow> {
  bool busy = false, failed = false;
  List<Map<String, dynamic>> requests = [];
  SupabaseClient get db => Supabase.instance.client;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant BookingWorkflow old) {
    super.didUpdateWidget(old);
    if (!busy) load();
  }

  Future<void> load() async {
    try {
      final rows = await db
          .from('booking_change_requests')
          .select()
          .eq('booking_id', widget.booking.id)
          .order('created_at', ascending: false)
          .limit(10);
      if (mounted) {
        setState(() {
          requests = rows;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  Future<void> run(String rpc, Map<String, dynamic> params) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await db.rpc(rpc, params: params);
      AppLiveData.instance.invalidate({
        'own:bookings',
        'own:booking_change_requests',
        'own:support_tickets',
      });
      await widget.onChanged();
      await load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is PostgrestException
                  ? e.message
                  : 'Unable to save. Check your connection and retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> quote() async {
    var input = widget.booking.quoteAmount?.toStringAsFixed(2) ?? '';
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Final quote'),
        content: TextFormField(
          initialValue: input,
          onChanged: (value) => input = value,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Final total amount (₹)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final n = double.tryParse(input);
              if (n != null && n.isFinite && n >= 0 && n <= 1000000000) {
                Navigator.pop(ctx, n);
              }
            },
            child: const Text('Send Quote'),
          ),
        ],
      ),
    );
    if (value != null && mounted) {
      await run('vendor_set_booking_quote', {
        'p_booking_id': widget.booking.id,
        'p_amount': value,
        'p_expected_version': widget.booking.quoteVersion,
      });
    }
  }

  Future<void> request(String kind) async {
    DateTime? date;
    TimeOfDay? time;
    if (kind == 'reschedule') {
      date = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateUtils.dateOnly(DateTime.now()),
        lastDate: DateTime(DateTime.now().year + 2, 12, 31),
      );
      if (date == null || !mounted) return;
      time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time == null || !mounted) return;
    }
    var input = '';
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          kind == 'cancel' ? 'Request Cancellation' : 'Request Reschedule',
        ),
        content: TextFormField(
          initialValue: input,
          onChanged: (value) => input = value,
          maxLength: 1000,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back'),
          ),
          TextButton(
            onPressed: () {
              if (input.trim().length >= 3) {
                Navigator.pop(ctx, input.trim());
              }
            },
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
    if (reason != null && mounted) {
      await run('customer_request_booking_change', {
        'p_booking_id': widget.booking.id,
        'p_kind': kind,
        'p_reason': reason,
        'p_date': date?.toIso8601String().split('T').first,
        'p_time': time == null
            ? null
            : '${time.hour.toString().padLeft(2, "0")}:${time.minute.toString().padLeft(2, "0")}:00',
      });
    }
  }

  Future<void> approveQuote() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve final quote?'),
        content: Text(
          '₹${widget.booking.quoteAmount?.toStringAsFixed(2)} will be the booking amount.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await run('customer_approve_booking_quote', {
        'p_booking_id': widget.booking.id,
        'p_expected_version': widget.booking.quoteVersion,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final pending = requests.any((r) => r['status'] == 'pending');
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Booking Updates',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (b.pricingUnit != null)
              Text(
                '${b.quantity} ${b.pricingUnit} × ₹${b.unitPrice?.toStringAsFixed(2) ?? "—"}',
              ),
            if (b.pricingType == 'starting_from') ...[
              Text(
                b.quoteAmount == null
                    ? 'Awaiting vendor final quote'
                    : 'Final quote: ₹${b.quoteAmount!.toStringAsFixed(2)}${b.quoteApprovedAt != null ? " • Approved" : " • Awaiting approval"}',
              ),
              if (b.status == 'pending')
                if (widget.vendor)
                  TextButton(
                    onPressed: busy ? null : quote,
                    child: const Text('Set Final Quote'),
                  )
                else if (b.quoteAmount != null && b.quoteApprovedAt == null)
                  FilledButton(
                    onPressed: busy ? null : approveQuote,
                    child: const Text('Approve Final Quote'),
                  ),
            ],
            if (failed)
              TextButton(
                onPressed: load,
                child: const Text('Unable to load change requests. Retry'),
              ),
            for (final r in requests)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r["kind"] == "cancel" ? "Cancellation" : "Reschedule"} • ${r["status"]}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (r['requested_date'] != null)
                      Text('${r["requested_date"]} ${r["requested_time"]} IST'),
                    Text(r['reason'] as String),
                    if (r['status'] == 'pending')
                      Wrap(
                        spacing: 8,
                        children: [
                          if (widget.vendor) ...[
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => run('vendor_resolve_booking_change', {
                                      'p_request_id': r['id'],
                                      'p_approve': false,
                                    }),
                              child: const Text('Reject'),
                            ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text(
                                            'Approve this change?',
                                          ),
                                          content: const Text(
                                            'The booking will be updated for both customer and vendor.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('Back'),
                                            ),
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text('Approve'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (ok == true && mounted) {
                                        await run(
                                          'vendor_resolve_booking_change',
                                          {
                                            'p_request_id': r['id'],
                                            'p_approve': true,
                                          },
                                        );
                                      }
                                    },
                              child: const Text('Approve'),
                            ),
                          ] else
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => run(
                                      'customer_withdraw_booking_change',
                                      {'p_request_id': r['id']},
                                    ),
                              child: const Text('Withdraw Request'),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            if (!widget.vendor &&
                !pending &&
                ['pending', 'accepted'].contains(b.status) &&
                b.vendorCompletedAt == null)
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: busy ? null : () => request('reschedule'),
                    child: const Text('Request Reschedule'),
                  ),
                  TextButton(
                    onPressed: busy ? null : () => request('cancel'),
                    child: const Text('Request Cancellation'),
                  ),
                ],
              ),
            if (busy) const Text('Saving…'),
          ],
        ),
      ),
    );
  }
}
