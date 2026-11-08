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
  String t(String en, String ta) => bookingText(context, en, ta);
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
        t('Maximum 3000 characters.', 'அதிகபட்சம் 3000 எழுத்துகள்.'),
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
              t(
                'Private notes saved.',
                'தனிப்பட்ட குறிப்புகள் சேமிக்கப்பட்டன.',
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
          t('Reload saved notes?', 'சேமித்த குறிப்புகளை மீண்டும் ஏற்றவா?'),
        ),
        content: Text(
          t(
            'Unsaved edits will be replaced with the latest saved notes.',
            'சேமிக்காத மாற்றங்களுக்குப் பதிலாக சமீபத்தில் சேமித்த குறிப்புகள் ஏற்றப்படும்.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(t('Back', 'பின்செல்')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(t('Reload', 'மீண்டும் ஏற்று')),
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
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError(
          t('Unable to open this link.', 'இணைப்பைத் திறக்க முடியவில்லை.'),
        );
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
            t('Booking Details', 'முன்பதிவு விவரங்கள்'),
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
                                  t(
                                    'Could not refresh booking details. Retry before making changes.',
                                    'விவரங்களைப் புதுப்பிக்க முடியவில்லை. மாற்றும் முன் மீண்டும் முயற்சிக்கவும்.',
                                  ),
                                ),
                                TextButton(
                                  onPressed: busy ? null : () => load(),
                                  child: Text(t('Retry', 'மீண்டும் முயற்சி')),
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
                      section(t('Service & business', 'சேவை மற்றும் வணிகம்'), [
                        info(
                          t('Business', 'வணிகம்'),
                          b.businessName ??
                              t(
                                'Unassigned business',
                                'வணிகம் ஒதுக்கப்படவில்லை',
                              ),
                        ),
                        info(t('Service', 'சேவை'), b.serviceName),
                        info(t('Event type', 'நிகழ்வு வகை'), b.eventTypeName),
                        info(
                          t('Booking amount', 'முன்பதிவுத் தொகை'),
                          '₹${b.price.toStringAsFixed(2)}',
                        ),
                      ]),
                      section(t('Customer', 'வாடிக்கையாளர்'), [
                        info(t('Name', 'பெயர்'), b.customerName),
                        info(t('Email', 'மின்னஞ்சல்'), b.customerEmail),
                        info(t('Phone', 'தொலைபேசி'), b.customerPhone),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed: canCall
                                  ? () => launch(
                                      Uri(scheme: 'tel', path: b.customerPhone),
                                    )
                                  : null,
                              icon: const Icon(Icons.call_outlined, size: 18),
                              label: Text(t('Call', 'அழைப்பு')),
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
                                  ? () => launch(Uri.https('wa.me', '/$digits'))
                                  : null,
                              icon: const Icon(Icons.chat_outlined, size: 18),
                              label: const Text('WhatsApp'),
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
                                  Uri(scheme: 'mailto', path: b.customerEmail),
                                ),
                                icon: const Icon(
                                  Icons.email_outlined,
                                  size: 18,
                                ),
                                label: Text(t('Email', 'மின்னஞ்சல்')),
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
                            t(
                              'WhatsApp requires a phone number with country code.',
                              'WhatsApp-க்கு நாட்டுக் குறியீட்டுடன் தொலைபேசி எண் தேவை.',
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                      ]),
                      section(t('Event details', 'நிகழ்வு விவரங்கள்'), [
                        info(
                          t('Schedule', 'நிகழ்வு நேரம்'),
                          bookingSchedule(context, b),
                        ),
                        if (b.eventStartTime == null)
                          Text(
                            t(
                              'Exact event time has not been provided.',
                              'சரியான நிகழ்வு நேரம் வழங்கப்படவில்லை.',
                            ),
                          ),
                        const SizedBox(height: 8),
                        info(
                          t('Guests', 'விருந்தினர்கள்'),
                          b.guestCount?.toString(),
                        ),
                        info(t('Location', 'இடம்'), b.location),
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
                            label: Text(t('Open Maps', 'வரைபடம் திற')),
                          ),
                        info(t('Requirements', 'தேவைகள்'), b.requirement),
                        info(t('Reason', 'காரணம்'), b.statusReason),
                        info(t('Full booking ID', 'முழு முன்பதிவு எண்'), b.id),
                        if (b.createdAt != null)
                          info(
                            t('Requested on', 'கோரிக்கை தேதி'),
                            '${bookingDate(context, b.createdAt!.toLocal())} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(b.createdAt!.toLocal()))}',
                          ),
                      ]),
                      section(
                        t(
                          'Private preparation notes',
                          'தனிப்பட்ட தயாரிப்புக் குறிப்புகள்',
                        ),
                        [
                          Text(
                            t(
                              'Only your vendor account can read these notes. Save before closing.',
                              'உங்கள் விற்பனையாளர் கணக்கில் மட்டுமே இவற்றைப் பார்க்க முடியும். மூடும் முன் சேமிக்கவும்.',
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
                              hintText: t(
                                'Team, equipment and preparation notes…',
                                'குழு, உபகரணங்கள் மற்றும் தயாரிப்புக் குறிப்புகள்…',
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
                                t('Save notes', 'குறிப்புகளைச் சேமி'),
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
                              t(
                                'Reload saved notes',
                                'சேமித்த குறிப்புகளை மீண்டும் ஏற்று',
                              ),
                            ),
                          ),
                        ],
                      ),
                      section(t('Booking timeline', 'முன்பதிவு வரலாறு'), [
                        if (history.isEmpty && !loading)
                          Text(t('No history available.', 'வரலாறு இல்லை.')),
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
                                            ? t(
                                                'Existing status recorded',
                                                'முந்தைய நிலை பதிவு செய்யப்பட்டது',
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
                                            'vendor' => t(
                                              'Vendor',
                                              'விற்பனையாளர்',
                                            ),
                                            'customer' => t(
                                              'Customer',
                                              'வாடிக்கையாளர்',
                                            ),
                                            _ => t('System', 'செயலி'),
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
                      ]),
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
                                  t('Accept', 'ஏற்கவும்'),
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
                                  t('Reject', 'நிராகரி'),
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
                                onPressed: busy
                                    ? null
                                    : () => action('completed'),
                                child: Text(
                                  t('Mark as Completed', 'முடிந்ததாகக் குறி'),
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
                                  t('Cancel booking', 'முன்பதிவை ரத்து செய்'),
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
