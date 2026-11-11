import 'package:flutter/material.dart';

import '../../models/booking_model.dart';
import '../../models/calendar_bookings.dart';
import '../../repositories/booking_repository.dart';
import '../../services/app_live_data.dart';
import '../../services/app_settings_controller.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/dashboard/minimal_booking_calendar.dart';
import '../../widgets/bookings/booking_history_card.dart';
import '../../widgets/bookings/booking_ui.dart';
import 'booking_details_screen.dart';

class EventorCalendar extends StatefulWidget {
  const EventorCalendar({
    super.key,
    this.repository,
    this.initialStatus = 'all',
    this.initialDate,
  });
  final BookingRepository? repository;
  final String initialStatus;
  final DateTime? initialDate;
  @override
  State<EventorCalendar> createState() => _EventorCalendarState();
}

class _EventorCalendarState extends State<EventorCalendar>
    with LiveDataState<EventorCalendar> {
  @override
  Set<String> get liveDatasets => {
    'own:bookings',
    'own:booking_status_history',
    'public:services',
  };
  @override
  Future<void> onLiveData(Set<String> changed) => load();
  late final repo = widget.repository ?? BookingRepository();
  late DateTime selected, month;
  List<BookingModel> rows = [];
  bool loading = true;
  Object? error;
  int generation = 0;
  String t(String en, String ta) => AppSettingsScope.of(context).text(en, ta);
  @override
  void initState() {
    super.initState();
    final requested = widget.initialDate ?? DateTime.now();
    selected = calendarDay(
      requested.year < 2026
          ? DateTime(2026)
          : requested.year > unlockedCalendarYear()
          ? DateTime(unlockedCalendarYear(), 12, 31)
          : requested,
    );
    month = DateTime(selected.year, selected.month);
    load();
  }

  Future<void> load() async {
    final request = ++generation;
    try {
      final data = await repo.getMyBookings();
      if (mounted && request == generation) {
        setState(() {
          rows = data;
          loading = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted && request == generation) {
        setState(() {
          error = e;
          loading = false;
        });
      }
    }
  }

  Future<void> open(BookingModel booking) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BookingDetailsScreen(booking: booking, repository: repo),
      ),
    );
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) {
    final scoped = rows
        .where(
          (b) =>
              widget.initialStatus == 'all' || b.status == widget.initialStatus,
        )
        .toList();
    final history = bookingsOnDay(scoped, selected);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        centerTitle: true,
        foregroundColor: const Color(0xFF73737D),
        title: Text(
          t('Calendar', 'நாட்காட்டி'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF17171B),
          ),
        ),
        backgroundColor: const Color(0xFFF8F8FA),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: AppShimmerRefreshIndicator(
        onRefresh: load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
          children: [
            if (loading) const ShimmerLoadingBar(),
            if (error != null)
              TextButton(
                onPressed: load,
                child: Text(
                  t(
                    'Could not refresh calendar. Retry',
                    'நாட்காட்டியை ஏற்ற முடியவில்லை. மீண்டும் முயற்சி',
                  ),
                ),
              ),
            MinimalBookingCalendar(
              bookings: scoped,
              focusedMonth: month,
              selectedDay: selected,
              onMonthChanged: (value) => setState(() => month = value),
              onDaySelected: (value) => setState(() => selected = value),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFE4E1E5)),
            const SizedBox(height: 20),
            if (history.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    t('History', 'வரலாறு'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF73737D),
                    ),
                  ),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bookingDate(context, selected),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF80152C),
                      ),
                    ),
                  ),
                  Text(
                    '${history.length} ${t('bookings', 'முன்பதிவுகள்')}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < history.length; i++)
                BookingHistoryCard(
                  booking: history[i],
                  last: i == history.length - 1,
                  onOpen: () => open(history[i]),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
