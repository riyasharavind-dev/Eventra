import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'booking_success_screen.dart';

import 'package:flutter/material.dart';

import '../../models/service_model.dart';
import '../../models/service_pricing.dart';
import '../../models/booking_draft.dart';
import '../../repositories/service_repository.dart';
import '../../repositories/booking_repository.dart';
import '../../repositories/customer_address_repository.dart';
import '../../widgets/customer_address_card.dart';
import '../../widgets/booking_summary_card.dart';
import '../../services/app_live_data.dart';

class BookingSummaryScreen extends StatefulWidget {
  const BookingSummaryScreen({
    super.key,
    required this.service,
    required this.draft,
    this.services,
    this.bookingRepository,
    this.addressRepository,
    this.serviceRepository,
  });
  final ServiceModel service;
  final BookingDraft draft;
  final List<ServiceModel>? services;
  final BookingRepository? bookingRepository;
  final CustomerAddressRepository? addressRepository;
  final ServiceRepository? serviceRepository;
  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryState();
}

class _BookingSummaryState extends State<BookingSummaryScreen> {
  late final serviceRepo = widget.serviceRepository ?? ServiceRepository();
  late final addressRepo =
      widget.addressRepository ?? CustomerAddressRepository();
  late final bookingRepo = widget.bookingRepository ?? BookingRepository();
  List<ServiceModel> rows = [];
  Map<String, Map<String, dynamic>> details = {};
  bool loading = true, failed = false, unavailable = false, sending = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (sending) return;
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final ids = (widget.services ?? [widget.service])
          .map((s) => s.id)
          .toSet()
          .toList();
      final fresh = await serviceRepo.getServicesByIds(ids);
      final overviews = await Future.wait(
        fresh.map((s) async {
          try {
            return MapEntry(s.id, await serviceRepo.getPublicOverview(s.id));
          } catch (_) {
            return MapEntry(s.id, <String, dynamic>{});
          }
        }),
      );
      if (!mounted) return;
      final byId = {for (final s in fresh) s.id: s};
      setState(() {
        rows = [
          for (final id in ids)
            if (byId[id] != null) byId[id]!,
        ];
        details = Map.fromEntries(overviews);
        unavailable = rows.length != ids.length || rows.any((s) => !s.isActive);
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  void message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
    }
  }

  Future<void> confirm() async {
    if (sending || loading || failed || unavailable || rows.isEmpty) return;
    if (!widget.draft.eventDateTime.isAfter(DateTime.now())) {
      message('Event date/time has passed. Edit event details.');
      return;
    }
    setState(() => sending = true);
    try {
      final contact = await addressRepo.load();
      if (contact?.trim().isNotEmpty != true) {
        message('Add and select Your Address before confirming.');
        return;
      }
      await bookingRepo.bookCart(
        services: rows,
        quantities: widget.draft.quantities,
        date: widget.draft.date,
        guests: widget.draft.guests,
        eventTime: widget.draft.eventTime,
        location: widget.draft.venue,
        requestId: widget.draft.requestId,
      );
      AppLiveData.instance.invalidate({'own:bookings'});
      if (mounted) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                BookingSuccessScreen(bookingIds: bookingRepo.lastBookingIds),
          ),
        );
        if (mounted) Navigator.pop(context, true);
      }
    } catch (error) {
      if (error is PostgrestException) {
        message(error.message);
        return;
      }
      message(
        'Unable to confirm. Retry, or refresh the summary if service pricing changed.',
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Widget fact(IconData icon, String title, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: const Color(0xFF80152C), size: 22),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: Color(0xFF73737D)),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final estimate = rows.any(
      (s) => s.pricing.type == ServicePricingType.startingFrom,
    );
    final total = rows.fold<double>(
      0,
      (v, s) => v + s.price * (draft.quantities[s.id] ?? 1),
    );
    return PopScope(
      canPop: !sending,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F8FA),
        appBar: AppBar(
          title: Text(
            AppSettingsScope.translate(
              context,
              "customer.booking_summary.c9a8bd9c",
            ),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: Color(0xFF17171B),
            ),
          ),
          backgroundColor: const Color(0xFFF8F8FA),
          elevation: 0,
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed:
                    loading || failed || unavailable || rows.isEmpty || sending
                    ? null
                    : confirm,
                icon: const Icon(Icons.event_available_outlined),
                label: Text(
                  sending ? 'Confirming…' : 'Confirm Booking',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF80152C),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (loading)
                const LinearProgressIndicator(color: Color(0xFF80152C)),
              if (failed)
                TextButton(
                  onPressed: load,
                  child: Text(
                    AppSettingsScope.translate(
                      context,
                      "customer.unable_to_load_summary_retry.96fdedd0",
                    ),
                  ),
                ),
              if (unavailable)
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    AppSettingsScope.translate(
                      context,
                      "customer.a_service_is_no_longer_available_go_back_and_.e12c71d8",
                    ),
                  ),
                ),
              for (final s in rows)
                BookingSummaryCard(
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 84,
                          height: 84,
                          child: s.gallery.isEmpty
                              ? const Icon(Icons.image_outlined)
                              : Image.network(
                                  s.gallery.first,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.image_outlined),
                                ),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (details[s.id]?['business_name'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(
                                  AppSettingsScope.translate(
                                    context,
                                    "customer.by_value0.f3856cb1",
                                    args: {
                                      "value0": details[s.id]!['business_name'],
                                    },
                                  ),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF595263),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 7),
                            if (details[s.id]?.isNotEmpty == true)
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFFFFBD00),
                                    size: 19,
                                  ),
                                  Text(
                                    AppSettingsScope.translate(
                                      context,
                                      "customer.value0_value1_reviews.76820ab0",
                                      args: {
                                        "value0":
                                            ((details[s.id]!['rating']
                                                        as num?) ??
                                                    0)
                                                .toStringAsFixed(1),
                                        "value1":
                                            details[s.id]!['review_count'] ?? 0,
                                      },
                                    ),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              BookingSummaryCard(
                title: AppSettingsScope.translate(
                  context,
                  "customer.event_details.1e4fa81b",
                ),
                icon: Icons.event_available_outlined,
                onEdit: sending ? null : () => Navigator.pop(context),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: fact(
                            Icons.calendar_today_outlined,
                            'Event Date',
                            MaterialLocalizations.of(context)
                                .formatMediumDate(draft.date),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 44,
                          color: const Color(0xFFDDD1D9),
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        Expanded(
                          flex: 3,
                          child: fact(
                            Icons.schedule_outlined,
                            'Time (IST)',
                            TimeOfDay(
                              hour: draft.hour,
                              minute: draft.minute,
                            ).format(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: fact(
                            Icons.groups_outlined,
                            'Guests',
                            '${draft.guests}',
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: fact(
                            Icons.location_on_outlined,
                            'Event Venue',
                            draft.venue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AbsorbPointer(
                absorbing: sending,
                child: CustomerAddressCard(
                  repository: addressRepo,
                  margin: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 12),
              BookingSummaryCard(
                title: AppSettingsScope.translate(
                  context,
                  "customer.price_breakdown.c2b1d7a6",
                ),
                icon: Icons.sell_outlined,
                child: Column(
                  children: [
                    for (final s in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                s.name,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                '${s.priceLabel}${s.pricing.needsUnit ? ' × ${draft.quantities[s.id] ?? 1}' : ''}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCECF3),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              estimate ? 'Base Estimate' : 'Total Amount',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF80152C),
                              ),
                            ),
                          ),
                          Text(
                            '₹${total.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF80152C),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (estimate)
                      Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          AppSettingsScope.translate(
                            context,
                            "customer.starting_from_services_require_a_final_quote_.dc889001",
                          ),
                          style: TextStyle(fontSize: 12, height: 1.4),
                        ),
                      ),
                  ],
                ),
              ),
              if (rows.length > 1)
                Text(
                  AppSettingsScope.translate(
                    context,
                    "customer.each_vendor_receives_a_separate_booking_reque.169a5578",
                  ),
                  style: TextStyle(fontSize: 12, color: Color(0xFF73737D)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
