import 'package:eventor_customer/services/app_settings_controller.dart';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          AppSettingsScope.translate(context, "customer.final_quote.be3d413b"),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Color(0xFF17171B),
          ),
        ),
        content: TextFormField(
          initialValue: input,
          onChanged: (value) => input = value,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: AppSettingsScope.translate(
              context,
              "customer.final_total_amount.869f8836",
            ),
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF73737D),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              AppSettingsScope.translate(context, "customer.cancel.19766ed6"),
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
            onPressed: () {
              final n = double.tryParse(input);
              if (n != null && n.isFinite && n >= 0 && n <= 1000000000) {
                Navigator.pop(ctx, n);
              }
            },
            child: Text(
              AppSettingsScope.translate(
                context,
                "customer.send_quote.23a42b97",
              ),
            ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          kind == 'cancel' ? 'Request Cancellation' : 'Request Reschedule',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Color(0xFF17171B),
          ),
        ),
        content: TextFormField(
          initialValue: input,
          onChanged: (value) => input = value,
          maxLength: 1000,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: AppSettingsScope.translate(
              context,
              "customer.reason.f81ab834",
            ),
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF73737D),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              AppSettingsScope.translate(context, "customer.back.76900f1b"),
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
            onPressed: () {
              if (input.trim().length >= 3) {
                Navigator.pop(ctx, input.trim());
              }
            },
            child: Text(
              AppSettingsScope.translate(
                context,
                "customer.send_request.19e428e1",
              ),
            ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          AppSettingsScope.translate(
            context,
            "customer.approve_final_quote.83c8cca3",
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
            "customer.value0_will_be_the_booking_amount.b4015904",
            args: {"value0": widget.booking.quoteAmount?.toStringAsFixed(2)},
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
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              AppSettingsScope.translate(context, "customer.back.76900f1b"),
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
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              AppSettingsScope.translate(context, "customer.approve.6007acbe"),
            ),
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
    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0EDF0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF80152C).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5E8EC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.update_rounded,
                    size: 18,
                    color: Color(0xFF80152C),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppSettingsScope.translate(
                      context,
                      "customer.booking_updates.90dc874b",
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF17171B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (b.pricingUnit != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${b.quantity} ${b.pricingUnit} × ₹${b.unitPrice?.toStringAsFixed(2) ?? "—"}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF73737D),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            if (b.pricingType == 'starting_from') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF0EDF0)),
                ),
                child: Text(
                  b.quoteAmount == null
                      ? 'Awaiting vendor final quote'
                      : 'Final quote: ₹${b.quoteAmount!.toStringAsFixed(2)}${b.quoteApprovedAt != null ? " • Approved" : " • Awaiting approval"}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF17171B),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (b.status == 'pending')
                if (widget.vendor)
                  TextButton(
                    onPressed: busy ? null : quote,
                    child: Text(
                      AppSettingsScope.translate(
                        context,
                        "customer.set_final_quote.67e33f93",
                      ),
                    ),
                  )
                else if (b.quoteAmount != null && b.quoteApprovedAt == null)
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF80152C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: busy ? null : approveQuote,
                    child: Text(
                      AppSettingsScope.translate(
                        context,
                        "customer.approve_final_quote.2db9267f",
                      ),
                    ),
                  ),
            ],
            if (failed)
              TextButton(
                onPressed: load,
                child: Text(
                  AppSettingsScope.translate(
                    context,
                    "customer.unable_to_load_change_requests_retry.e3b97912",
                  ),
                ),
              ),
            for (final r in requests)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF0EDF0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r["kind"] == "cancel" ? "Cancellation" : "Reschedule"} • ${r["status"]}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF17171B),
                      ),
                    ),
                    if (r['requested_date'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          AppSettingsScope.translate(
                            context,
                            "customer.value0_value1_ist.1327bc96",
                            args: {
                              "value0": r["requested_date"],
                              "value1": r["requested_time"],
                            },
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF73737D),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        r['reason'] as String,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF17171B),
                        ),
                      ),
                    ),
                    if (r['status'] == 'pending') ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (widget.vendor) ...[
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFC62828),
                                side: const BorderSide(color: Color(0xFFC62828)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: busy
                                  ? null
                                  : () => run('vendor_resolve_booking_change', {
                                      'p_request_id': r['id'],
                                      'p_approve': false,
                                    }),
                              child: Text(
                                AppSettingsScope.translate(
                                  context,
                                  "customer.reject.ab604a36",
                                ),
                              ),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF80152C),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: busy
                                  ? null
                                  : () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          backgroundColor: Colors.white,
                                          title: Text(
                                            AppSettingsScope.translate(
                                              context,
                                              "customer.approve_this_change.7d969ae8",
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
                                              "customer.the_booking_will_be_updated_for_both_customer.733f5c2d",
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
                                                foregroundColor:
                                                    const Color(0xFF73737D),
                                              ),
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: Text(
                                                AppSettingsScope.translate(
                                                  context,
                                                  "customer.back.76900f1b",
                                                ),
                                              ),
                                            ),
                                            FilledButton(
                                              style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF80152C),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: Text(
                                                AppSettingsScope.translate(
                                                  context,
                                                  "customer.approve.6007acbe",
                                                ),
                                              ),
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
                              child: Text(
                                AppSettingsScope.translate(
                                  context,
                                  "customer.approve.6007acbe",
                                ),
                              ),
                            ),
                          ] else
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFC62828),
                                side: const BorderSide(color: Color(0xFFC62828)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: busy
                                  ? null
                                  : () => run(
                                      'customer_withdraw_booking_change',
                                      {'p_request_id': r['id']},
                                    ),
                              child: Text(
                                AppSettingsScope.translate(
                                  context,
                                  "customer.withdraw_request.af79e0e4",
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            if (!widget.vendor &&
                !pending &&
                ['pending', 'accepted'].contains(b.status) &&
                b.vendorCompletedAt == null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF80152C),
                      side: const BorderSide(color: Color(0xFF80152C)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    onPressed: busy ? null : () => request('reschedule'),
                    icon: const Icon(Icons.calendar_month_outlined, size: 16),
                    label: Text(
                      AppSettingsScope.translate(
                        context,
                        "customer.request_reschedule.c189bbb7",
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC62828),
                      side: const BorderSide(color: Color(0xFFC62828)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    onPressed: busy ? null : () => request('cancel'),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: Text(
                      AppSettingsScope.translate(
                        context,
                        "customer.request_cancellation.c950fabd",
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
            if (busy) ...[
              const SizedBox(height: 8),
              Text(
                AppSettingsScope.translate(context, "customer.saving.23e39291"),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF73737D),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
