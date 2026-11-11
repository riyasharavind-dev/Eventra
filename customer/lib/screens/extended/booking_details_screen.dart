import '../../widgets/bookings/booking_contact_actions.dart';
import 'booking_issue_screen.dart';
import '../../widgets/bookings/booking_workflow.dart';

import 'package:flutter/material.dart';

import '../../models/booking_model.dart';
import '../../repositories/booking_repository.dart';
import '../../services/app_live_data.dart';
import '../../services/app_settings_controller.dart';
import '../../widgets/bookings/booking_ui.dart';
import '../../widgets/common/app_shimmer.dart';

class BookingDetailsScreen extends StatefulWidget {
  const BookingDetailsScreen({
    super.key,
    required this.booking,
    this.repository,
  });
  final BookingModel booking;
  final BookingRepository? repository;
  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen>
    with LiveDataState<BookingDetailsScreen> {
  @override
  Set<String> get liveDatasets => {
    'own:bookings',
    'own:booking_status_history',
    'public:services',
    'public:vendors',
  };
  @override
  Future<void> onLiveData(Set<String> changed) => load();
  late BookingModel booking = widget.booking;
  late final repo = widget.repository ?? BookingRepository();
  bool failed = false;
  int generation = 0;
  String t(String en, String ta) => AppSettingsScope.of(context).text(en, ta);
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final request = ++generation;
    try {
      final data = await repo.getBookingById(booking.id);
      if (mounted && request == generation) {
        setState(() {
          if (data != null) booking = data;
          failed = data == null;
        });
      }
    } catch (_) {
      if (mounted && request == generation) setState(() => failed = true);
    }
  }

  Widget section(String title, List<Widget> children) => Container(
    margin: const EdgeInsets.only(top: 14),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF17171B),
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
  Widget row(IconData icon, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF73737D)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13, height: 1.4)),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        centerTitle: true,
        foregroundColor: const Color(0xFF73737D),
        title: Text(
          t('Booking Details', 'முன்பதிவு விவரங்கள்'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF17171B),
          ),
        ),
        backgroundColor: const Color(0xFFF8F8FA),
        surfaceTintColor: Colors.transparent,
      ),
      body: AppShimmerRefreshIndicator(
        onRefresh: load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: bookingPhoto(b.serviceGallery.firstOrNull, height: 220),
            ),
            if (failed)
              TextButton(
                onPressed: load,
                child: Text(
                  t(
                    'Unable to refresh. Retry',
                    'புதுப்பிக்க முடியவில்லை. மீண்டும் முயற்சி',
                  ),
                ),
              ),
            section(b.serviceName, [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#${shortBookingId(b.id)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  BookingStatusChip(status: b.status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '₹${b.price.toStringAsFixed(b.price % 1 == 0 ? 0 : 2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF80152C),
                ),
              ),
              row(Icons.event_outlined, bookingSchedule(context, b)),
            ]),
            BookingWorkflow(booking: b, onChanged: load),
            BookingContactActions(bookingId: b.id),
            section(t('Vendor Details', 'விற்பனையாளர் விவரங்கள்'), [
              row(Icons.person_outline, b.vendorName),
              if (b.vendorEmail.isNotEmpty)
                row(Icons.mail_outline, b.vendorEmail),
            ]),
            section(t('Event Location', 'நிகழ்ச்சி இடம்'), [
              row(
                Icons.location_on_outlined,
                b.location.isEmpty
                    ? t('Location not specified', 'இடம் குறிப்பிடப்படவில்லை')
                    : b.location,
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF80152C),
                  side: const BorderSide(color: Color(0xFF80152C)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookingIssueScreen(bookingId: b.id),
                  ),
                ),
                icon: const Icon(Icons.help_outline, size: 18),
                label: Text(
                  AppSettingsScope.translate(
                    context,
                    "customer.report_a_booking_issue.229ba754",
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            section(t('Additional Information', 'கூடுதல் தகவல்'), [
              if (b.eventTypeName?.isNotEmpty == true)
                row(Icons.celebration_outlined, b.eventTypeName!),
              if (b.guestCount != null)
                row(
                  Icons.people_outline,
                  '${t('Guests', 'விருந்தினர்கள்')}: ${b.guestCount}',
                ),
              if (b.requirement?.isNotEmpty == true)
                row(Icons.notes_outlined, b.requirement!),
              if (b.statusReason?.isNotEmpty == true)
                row(Icons.info_outline, b.statusReason!),
              if (b.createdAt != null)
                row(
                  Icons.schedule_outlined,
                  '${t('Created on', 'உருவாக்கப்பட்டது')}: ${bookingDate(context, b.createdAt)}',
                ),
            ]),
          ],
        ),
      ),
    );
  }
}
