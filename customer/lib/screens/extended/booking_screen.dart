import 'package:eventor_customer/services/app_settings_controller.dart';

import '../../core/theme/app_icon_colors.dart';

import 'my_profile_screen.dart';
import '../../widgets/bookings/booking_quantity_field.dart';
import '../../models/booking_draft.dart';
import '../../repositories/customer_address_repository.dart';
import '../../repositories/service_repository.dart';
import '../../widgets/customer_address_card.dart';
import 'booking_summary_screen.dart';

import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/service_model.dart';
import '../../repositories/booking_repository.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({
    super.key,
    required this.service,
    this.services,
    this.initialDraft,
    this.bookingRepository,
    this.addressRepository,
    this.serviceRepository,
  });
  final ServiceModel service;
  final List<ServiceModel>? services;
  final BookingDraft? initialDraft;
  final BookingRepository? bookingRepository;
  final CustomerAddressRepository? addressRepository;
  final ServiceRepository? serviceRepository;
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final form = GlobalKey<FormState>();
  final guests = TextEditingController(), address = TextEditingController();
  late final requestId =
      widget.initialDraft?.requestId ??
      List.generate(
        24,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
  final quantities = <String, int>{};
  DateTime? date;
  TimeOfDay? time;
  bool saving = false;
  late final addressRepo =
      widget.addressRepository ?? CustomerAddressRepository();
  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft;
    if (draft != null) {
      quantities.addAll(draft.quantities);
      date = draft.date;
      time = TimeOfDay(hour: draft.hour, minute: draft.minute);
      guests.text = draft.guests.toString();
      address.text = draft.venue;
    }
  }

  @override
  void dispose() {
    guests.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final result = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: DateTime(today.year + 2, 12, 31),
      initialDate: date != null && !date!.isBefore(today) ? date : today,
    );
    if (result != null && mounted) setState(() => date = result);
  }

  Future<void> pickTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: time ?? TimeOfDay.now(),
    );
    if (result != null && mounted) setState(() => time = result);
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> submit() async {
    if (saving || !form.currentState!.validate()) return;
    if (date == null || time == null) {
      message(
        AppSettingsScope.translate(
          context,
          "customer.choose_the_event_date_and_time.3ff750ce",
        ),
      );
      return;
    }
    final draft = BookingDraft(
      requestId: requestId,
      quantities: Map.unmodifiable(quantities),
      date: date!,
      hour: time!.hour,
      minute: time!.minute,
      guests: int.parse(guests.text.trim()),
      venue: address.text.trim(),
    );
    if (!draft.eventDateTime.isAfter(DateTime.now())) {
      message('Choose a future event date and time.');
      return;
    }
    setState(() => saving = true);
    try {
      final contact = await addressRepo.load();
      if (!mounted) return;
      if (contact?.trim().isNotEmpty != true) {
        message('Add and select Your Address before continuing.');
        return;
      }
      final booked = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => BookingSummaryScreen(
            service: widget.service,
            services: widget.services,
            draft: draft,
            bookingRepository: widget.bookingRepository,
            addressRepository: addressRepo,
            serviceRepository: widget.serviceRepository,
          ),
        ),
      );
      if (mounted && booked == true) Navigator.pop(context, true);
    } catch (_) {
      message('Unable to continue. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget picker(
    String label,
    String value,
    IconData icon,
    VoidCallback action,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: InkWell(
      onTap: saving ? null : action,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF0EDF0)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppIconColors.standard, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF73737D),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF17171B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppIconColors.standard,
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        title: Text(
          AppSettingsScope.translate(context, "customer.book_service.f6297c07"),
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
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: SizedBox(
          height: 50,
          child: FilledButton(
            onPressed: saving ? null : submit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF80152C),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(saving ? 'Please wait…' : 'Continue'),
          ),
        ),
      ),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              (widget.services?.length ?? 1) > 1
                  ? '${widget.services!.length} selected services'
                  : widget.service.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF17171B),
              ),
            ),
            const SizedBox(height: 20),
            for (final service in widget.services ?? [widget.service])
              if (service.pricing.needsUnit)
                BookingQuantityField(
                  service: service,
                  initialValue: quantities[service.id] ?? 1,
                  enabled: !saving,
                  onChanged: (n) => quantities[service.id] = n,
                ),
            picker(
              'Event Date',
              date == null
                  ? 'Select event date'
                  : MaterialLocalizations.of(context).formatMediumDate(date!),
              Icons.calendar_month_outlined,
              pickDate,
            ),
            picker(
              'Event Time (IST)',
              time == null ? 'Select event time' : time!.format(context),
              Icons.schedule_outlined,
              pickTime,
            ),
            TextFormField(
              controller: guests,
              enabled: !saving,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppSettingsScope.translate(
                  context,
                  "customer.guest_count.0f6d6f1e",
                ),
                hintText: AppSettingsScope.translate(
                  context,
                  "customer.example_200.b369efd7",
                ),
                prefixIcon: const Icon(
                  Icons.groups_outlined,
                  color: AppIconColors.standard,
                ),
              ),
              validator: (value) => (int.tryParse(value?.trim() ?? '') ?? 0) > 0
                  ? null
                  : AppSettingsScope.translate(
                      context,
                      "customer.enter_a_valid_guest_count.810dc698",
                    ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: address,
              enabled: !saving,
              minLines: 3,
              maxLines: 5,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: AppSettingsScope.translate(
                  context,
                  "customer.event_address.654d5cd2",
                ),
                hintText: AppSettingsScope.translate(
                  context,
                  "customer.venue_house_name_street_area_city_and_landmar.10f19f5f",
                ),
                alignLabelWithHint: true,
                prefixIcon: const Icon(
                  Icons.location_on_outlined,
                  color: AppIconColors.standard,
                ),
              ),
              validator: (value) => (value?.trim().length ?? 0) >= 5
                  ? null
                  : AppSettingsScope.translate(
                      context,
                      "customer.enter_the_event_address.05c75f29",
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                AppSettingsScope.translate(
                  context,
                  "customer.share_the_event_address_so_the_vendor_knows_t.7253001f",
                ),
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Color(0xFF73737D),
                ),
              ),
            ),
            const SizedBox(height: 12),
            CustomerAddressCard(
              repository: addressRepo,
              margin: EdgeInsets.zero,
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF80152C),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onPressed: saving
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyProfileScreen(),
                      ),
                    ),
              icon: const Icon(Icons.phone_outlined, size: 18),
              label: Text(
                AppSettingsScope.translate(
                  context,
                  "customer.check_your_contact_phone.05827590",
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
