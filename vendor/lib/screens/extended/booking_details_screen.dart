import '../../widgets/bookings/booking_workflow.dart';

import 'package:eventor_vendor/services/app_settings_controller.dart';
import 'package:eventor_vendor/core/theme/app_icon_colors.dart';

import '../../services/app_live_data.dart';
import '../../widgets/vendor_page_scaffold.dart';
import '../../widgets/common/app_shimmer.dart';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/booking_model.dart';
import '../../repositories/booking_repository.dart';
import '../../widgets/bookings/booking_ui.dart';

class BookingDetailsScreen extends StatefulWidget {
  final BookingModel booking;
  final VoidCallback? onChanged;
  final BookingRepository? repository;
  const BookingDetailsScreen({
    super.key,
    required this.booking,
    this.onChanged,
    this.repository,
  });
  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen>
    with LiveDataState<BookingDetailsScreen> {
  @override
  bool get liveCanRefresh => !busy;
  @override
  Set<String> get liveDatasets => {
    'own:bookings',
    'own:booking_status_history',
    'own:booking_vendor_notes',
  };
  @override
  Future<void> onLiveData(Set<String> changed) async {
    await load();
  }

  late final BookingRepository repo;
  late int noteVersion;
  late BookingModel booking;
  late final TextEditingController notes;
  List<Map<String, dynamic>> history = [];
  bool loading = true, busy = false;
  Object? error;
  String t(String en) => AppSettingsScope.source(context, en);
  @override
  void initState() {
    super.initState();
    repo = widget.repository ?? BookingRepository();
    booking = widget.booking;
    noteVersion = booking.noteVersion;
    notes = TextEditingController(text: booking.vendorNote);
    load(syncNotes: true);
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Future<void> load({bool syncNotes = false}) async {
    try {
      final fresh = await repo.getBooking(booking.id);
      final events = await repo.history(booking.id);
      if (!mounted) {
        return;
      }
      setState(() {
        booking = fresh;
        history = events;
        error = null;
        loading = false;
        if (syncNotes) {
          notes.text = fresh.vendorNote;
          noteVersion = fresh.noteVersion;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          loading = false;
        });
      }
    }
  }

  Future<void> action(String status) async {
    if (busy) {
      return;
    }
    setState(() => busy = true);
    try {
      if (await confirmBookingChange(context, repo, booking, status)) {
        widget.onChanged?.call();
        await load();
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> saveNotes() async {
    if (busy) {
      return;
    }
    if (notes.text.length > 3000) {
      bookingError(
        context,
        AppSettingsScope.translate(
          context,
          "vendor.maximum_3000_characters.2ea26a94",
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      noteVersion = await repo.saveNote(
        booking,
        notes.text,
        expectedVersion: noteVersion,
      );
      widget.onChanged?.call();
      await load(syncNotes: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppSettingsScope.translate(
                context,
                "vendor.private_notes_saved.4ff704fa",
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        bookingError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> reloadNotes() async {
    if (busy || loading) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          AppSettingsScope.translate(
            context,
            "vendor.reload_saved_notes.2bdd54cf",
          ),
        ),
        content: Text(
          AppSettingsScope.translate(
            context,
            "vendor.unsaved_edits_will_be_replaced_with_the_lates.6d2d9b81",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(
              AppSettingsScope.translate(context, "vendor.back.76900f1b"),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(
              AppSettingsScope.translate(context, "vendor.reload.bdc090ec"),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => busy = true);
    try {
      await load(syncNotes: true);
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> launch(Uri uri) async {
    final l10n = AppSettingsScope.localizationOf(context);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError(l10n.tr("vendor.unable_to_open_this_link.be059945"));
      }
    } catch (e) {
      if (mounted) {
        bookingError(context, e);
      }
    }
  }

  Widget section(String title, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(18),
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF17171B),
          ),
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    ),
  );
  Widget info(String title, String? value) =>
      value == null || value.trim().isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(value),
            ],
          ),
        );
  @override
  Widget build(BuildContext context) {
    final b = booking, colors = Theme.of(context).colorScheme;
    final digits = b.customerPhone?.replaceAll(RegExp(r'\D'), '') ?? '';
    final canCall = digits.length >= 7 && digits.length <= 15;
    final canWhatsApp = digits.length >= 11 && digits.length <= 15;
    final hasCoordinates =
        b.latitude != null &&
        b.longitude != null &&
        b.latitude!.isFinite &&
        b.longitude!.isFinite &&
        b.latitude!.abs() <= 90 &&
        b.longitude!.abs() <= 180;
    return PopScope(
      canPop: !busy,
      child: VendorPageScaffold(
        backgroundColor: const Color(0xFFF8F8FA),
        appBar: AppBar(
          title: Text(
            AppSettingsScope.translate(
              context,
              "vendor.booking_details.a55a9692",
            ),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          leading: BackButton(
            onPressed: busy ? null : () => Navigator.maybePop(context),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              if (busy || loading) const ShimmerLoadingBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (error != null)
                        Card(
                          color: colors.errorContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppSettingsScope.translate(
                                    context,
                                    "vendor.could_not_refresh_booking_details_retry_befor.40815c5b",
                                  ),
                                ),
                                TextButton(
                                  onPressed: busy ? null : () => load(),
                                  child: Text(
                                    AppSettingsScope.translate(
                                      context,
                                      "vendor.retry.942087cc",
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (b.serviceGallery.isNotEmpty) ...[
                        SizedBox(
                          height: 210,
                          child: PageView.builder(
                            itemCount: b.serviceGallery.length,
                            itemBuilder: (context, index) => Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      b.serviceGallery[index],
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, error, stack) =>
                                          const ColoredBox(
                                            color: Color(0xFFF5F0F2),
                                            child: Icon(
                                              Icons
                                                  .image_not_supported_outlined,
                                              size: 40,
                                            ),
                                          ),
                                    ),
                                    if (b.serviceGallery.length > 1)
                                      Positioned(
                                        bottom: 10,
                                        right: 10,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            '${index + 1}/${b.serviceGallery.length}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      Text(
                        b.serviceName,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '#${shortBookingId(b.id)}',
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                          BookingStatusChip(status: b.status),
                        ],
                      ),
                      const SizedBox(height: 20),
                      section(
                        AppSettingsScope.translate(
                          context,
                          "vendor.service_business.4987282f",
                        ),
                        [
                          info(
                            AppSettingsScope.translate(
                              context,
                              "vendor.business.76f68a75",
                            ),
                            b.businessName ??
                                AppSettingsScope.translate(
                                  context,
                                  "vendor.unassigned_business.2e6ea6db",
                                ),
                          ),
                          info(
                            AppSettingsScope.translate(
                              context,
                              "vendor.service.d677190e",
                            ),
                            b.serviceName,
                          ),
                          info(
                            AppSettingsScope.translate(
                              context,
                              "vendor.event_type.70d81703",
                            ),
                            b.eventTypeName,
                          ),
                          info(
                            AppSettingsScope.translate(
                              context,
                              "vendor.booking_amount.cd0bd2f0",
                            ),
                            '₹${b.price.toStringAsFixed(2)}',
                          ),
                        ],
                      ),
                      section(
                        AppSettingsScope.translate(
                          context,
                          "vendor.customer.bf376338",
                        ),
                        [
                          info(
                            AppSettingsScope.translate(
                              context,
                              "vendor.name.dcd1d522",
                            ),
                            b.customerName,
                          ),
                          info(
                            AppSettingsScope.translate(
                              context,
                              "vendor.email.969ccbd3",
                            ),
                            b.customerEmail,
                          ),
                          info(
                            AppSettingsScope.translate(
                              context,
                              "vendor.phone.63dceb88",
                            ),
                            b.customerPhone,
                          ),
                          if (b.customerAddress?.trim().isNotEmpty == true)
                            info('Customer Address', b.customerAddress),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              OutlinedButton.icon(
                                onPressed: canCall
                                    ? () => launch(
                                        Uri(
                                          scheme: 'tel',
                                          path: b.customerPhone,
                                        ),
                                      )
                                    : null,
                                icon: const Icon(Icons.call_outlined, size: 18),
                                label: Text(
                                  AppSettingsScope.translate(
                                    context,
                                    "vendor.call.d6e645b7",
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF80152C),
                                  side: const BorderSide(
                                    color: Color(0xFF80152C),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: canWhatsApp
                                    ? () =>
                                          launch(Uri.https('wa.me', '/$digits'))
                                    : null,
                                icon: const Icon(Icons.chat_outlined, size: 18),
                                label: Text(
                                  AppSettingsScope.translate(
                                    context,
                                    "vendor.whatsapp.6a40edf1",
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF25D366),
                                  side: const BorderSide(
                                    color: Color(0xFF25D366),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              if (b.customerEmail.isNotEmpty)
                                OutlinedButton.icon(
                                  onPressed: () => launch(
                                    Uri(
                                      scheme: 'mailto',
                                      path: b.customerEmail,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.email_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    AppSettingsScope.translate(
                                      context,
                                      "vendor.email.969ccbd3",
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF17171B),
                                    side: const BorderSide(
                                      color: Color(0xFFE8E5E8),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (canCall && !canWhatsApp)
                            Text(
                              AppSettingsScope.translate(
                                context,
                                "vendor.whatsapp_requires_a_phone_number_with_country.e24824c7",
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      section(
                        AppSettingsScope.translate(
                          context,
                          "vendor.event_details.f9c7f3d8",
                        ),
                        [
                          info(
                            AppSettingsScope.translate(
                              context,
                              "vendor.schedule.f4830a1d",
                            ),
                            bookingSchedule(context, b),
                          ),
                          if (b.eventStartTime == null)
                            Text(
                              AppSettingsScope.translate(
                                context,
                                "vendor.exact_event_time_has_not_been_provided.3169f851",
                              ),
                            ),
                          const SizedBox(height: 8),
                          info(
                            AppSettingsScope.translate(
                              context,
                              "vendor.guests.3c8e0fde",
                            ),
                            b.guestCount?.toString(),
                          ),
                          info(
                            AppSettingsScope.translate(
                              context,
                              "vendor.location.15b61974",
                            ),
                            b.location,
                          ),
                          if (hasCoordinates || b.location.trim().isNotEmpty)
                            TextButton.icon(
                              onPressed: () => launch(
                                Uri.https('www.google.com', '/maps/search/', {
                                  'api': '1',
                                  'query': hasCoordinates
                                      ? '${b.latitude},${b.longitude}'
                                      : b.location,
                                }),
                              ),
                              icon: const Icon(Icons.map_outlined),
                              label: Text(
                                AppSettingsScope.translate(
                                  context,
                                  "vendor.open_maps.4fae8f1c",
                                ),
                              ),
                            ),
                          info(
                            AppSettingsScope.translate(
                              context,
                              "vendor.requirements.e0cdd07f",
                            ),
                            b.requirement,
                          ),
                          info(
                            AppSettingsScope.translate(
                              context,
                              "vendor.reason.f81ab834",
                            ),
                            b.statusReason,
                          ),
                          info(
                            AppSettingsScope.translate(
                              context,
                              "vendor.full_booking_id.c5159e27",
                            ),
                            b.id,
                          ),
                          if (b.createdAt != null)
                            info(
                              AppSettingsScope.translate(
                                context,
                                "vendor.requested_on.0ec52c00",
                              ),
                              '${bookingDate(context, b.createdAt!.toLocal())} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(b.createdAt!.toLocal()))}',
                            ),
                        ],
                      ),
                      section(
                        AppSettingsScope.translate(
                          context,
                          "vendor.private_preparation_notes.fe272e4d",
                        ),
                        [
                          Text(
                            AppSettingsScope.translate(
                              context,
                              "vendor.only_your_vendor_account_can_read_these_notes.1c7995c7",
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: notes,
                            maxLines: 4,
                            maxLength: 3000,
                            enabled: !busy && !loading && error == null,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFFBF9FA),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE8E5E8),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE8E5E8),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFF80152C),
                                  width: 1.5,
                                ),
                              ),
                              hintText: AppSettingsScope.translate(
                                context,
                                "vendor.team_equipment_and_preparation_notes.b432cc84",
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF80152C),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: busy || loading || error != null
                                  ? null
                                  : saveNotes,
                              icon: const Icon(Icons.save_outlined, size: 18),
                              label: Text(
                                AppSettingsScope.translate(
                                  context,
                                  "vendor.save_notes.eb76a6cc",
                                ),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF73737D),
                            ),
                            onPressed: busy || loading ? null : reloadNotes,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text(
                              AppSettingsScope.translate(
                                context,
                                "vendor.reload_saved_notes.b9731050",
                              ),
                            ),
                          ),
                        ],
                      ),
                      section(
                        AppSettingsScope.translate(
                          context,
                          "vendor.booking_timeline.68c7ef54",
                        ),
                        [
                          if (history.isEmpty && !loading)
                            Text(
                              AppSettingsScope.translate(
                                context,
                                "vendor.no_history_available.6a83ad0c",
                              ),
                            ),
                          ...history.map((h) {
                            final when = DateTime.tryParse(
                              h['occurred_at'].toString(),
                            )?.toLocal();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFBF9FA),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFF0EDF0),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5E8EC),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.history,
                                      color: AppIconColors.standard,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          h['entry_kind'] == 'snapshot'
                                              ? AppSettingsScope.translate(
                                                  context,
                                                  "vendor.existing_status_recorded.3bfcb441",
                                                )
                                              : bookingStatus(
                                                  context,
                                                  h['status'].toString(),
                                                ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: Color(0xFF17171B),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          [
                                            if (h['entry_kind'] == 'snapshot')
                                              bookingStatus(
                                                context,
                                                h['status'].toString(),
                                              ),
                                            if (when != null)
                                              '${bookingDate(context, when)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(when))}',
                                            switch (h['actor_kind']) {
                                              'vendor' =>
                                                AppSettingsScope.translate(
                                                  context,
                                                  "vendor.vendor.f8aa82b4",
                                                ),
                                              'customer' =>
                                                AppSettingsScope.translate(
                                                  context,
                                                  "vendor.customer.bf376338",
                                                ),
                                              _ => AppSettingsScope.translate(
                                                context,
                                                "vendor.system.6725e7bb",
                                              ),
                                            },
                                            if (h['reason'] != null)
                                              h['reason'].toString(),
                                          ].join(' · '),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF73737D),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                      if (!loading && error == null)
                        BookingWorkflow(
                          booking: b,
                          vendor: true,
                          onChanged: () => load(),
                        ),
                      if (!loading && error == null)
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            if (b.status == 'pending') ...[
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF80152C),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 2,
                                  shadowColor: const Color(0xFF80152C)
                                      .withValues(alpha: 0.3),
                                ),
                                onPressed: busy
                                    ? null
                                    : () => action('accepted'),
                                child: Text(
                                  AppSettingsScope.translate(
                                    context,
                                    "vendor.accept.89713b9c",
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFC62828),
                                  side: const BorderSide(
                                    color: Color(0xFFEF9A9A),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: busy
                                    ? null
                                    : () => action('rejected'),
                                child: Text(
                                  AppSettingsScope.translate(
                                    context,
                                    "vendor.reject.ab604a36",
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                            if (b.status == 'accepted')
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF00A86B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 2,
                                  shadowColor: const Color(0xFF00A86B)
                                      .withValues(alpha: 0.3),
                                ),
                                onPressed: busy || b.awaitingCompletion
                                    ? null
                                    : () => action('completed'),
                                child: Text(
                                  b.awaitingCompletion
                                      ? 'Awaiting customer confirmation'
                                      : AppSettingsScope.translate(
                                          context,
                                          "vendor.mark_as_completed.bb33aaa1",
                                        ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            if (['pending', 'accepted'].contains(b.status))
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFC62828),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                                onPressed: busy
                                    ? null
                                    : () => action('cancelled'),
                                child: Text(
                                  AppSettingsScope.translate(
                                    context,
                                    "vendor.cancel_booking.cb33063e",
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
