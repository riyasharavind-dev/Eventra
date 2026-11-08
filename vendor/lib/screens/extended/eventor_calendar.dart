import '../../services/app_live_data.dart';
import '../../widgets/vendor_page_scaffold.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/dashboard/minimal_booking_calendar.dart';

import 'package:flutter/material.dart';

import '../../models/booking_model.dart';
import '../../models/calendar_bookings.dart';
import '../../models/dashboard_data.dart';
import '../../repositories/dashboard_repository.dart';
import 'booking_details_screen.dart';
import '../../widgets/bookings/booking_ui.dart';
import '../../widgets/dashboard/booking_month_calendar.dart';
import '../../widgets/bookings/booking_history_card.dart';

class EventorCalendar extends StatefulWidget {
  final DashboardRepository? repository;
  final String initialBusiness, initialStatus;
  final DateTime? initialDate;
  const EventorCalendar({
    super.key,
    this.repository,
    this.initialBusiness = 'all',
    this.initialStatus = 'all',
    this.initialDate,
  });
  @override
  State<EventorCalendar> createState() => _EventorCalendarState();
}

class _EventorCalendarState extends State<EventorCalendar>
    with LiveDataState<EventorCalendar> {
  @override
  Set<String> get liveDatasets => {
    'own:bookings',
    'own:businesses',
    'own:services',
  };
  @override
  Future<void> onLiveData(Set<String> changed) async {
    await load();
  }

  late final DashboardRepository repo;
  CalendarData? data;
  late DateTime selected, month;
  late String business, status;
  bool loading = true, opening = false;
  Object? error;
  int generation = 0;
  String t(String en, String ta) => bookingText(context, en, ta);
  @override
  void initState() {
    super.initState();
    repo = widget.repository ?? DashboardRepository();
    final requested = widget.initialDate ?? DateTime.now();
    selected = calendarDay(
      requested.year < 2026
          ? DateTime(2026)
          : requested.year > unlockedCalendarYear()
          ? DateTime(unlockedCalendarYear(), 12, 31)
          : requested,
    );
    month = DateTime(selected.year, selected.month);
    business = widget.initialBusiness;
    status = widget.initialStatus;
    load();
  }

  Future<void> load() async {
    final request = ++generation;
    setState(() {
      if (!liveRefreshing) loading = true;
      error = null;
    });
    try {
      final fresh = await repo.calendar();
      if (!mounted || request != generation) {
        return;
      }
      setState(() {
        data = fresh;
        loading = false;
      });
    } catch (e) {
      if (mounted && request == generation) {
        setState(() {
          error = e;
          loading = false;
        });
      }
    }
  }

  Future<void> details(BookingModel booking) async {
    if (opening) {
      return;
    }
    setState(() => opening = true);
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => BookingDetailsScreen(booking: booking),
        ),
      );
      if (mounted) {
        await load();
      }
    } finally {
      if (mounted) {
        setState(() => opening = false);
      }
    }
  }

  Widget empty(String message) => Padding(
    padding: const EdgeInsets.all(18),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final scoped = calendarScope(
      data?.bookings ?? [],
      business: business,
      status: status,
    );
    final selectedRows = bookingsOnDay(scoped, selected);
    return VendorPageScaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
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
        color: const Color(0xFF80152C),
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (loading) const ShimmerLoadingBar(),
            if (error != null)
              Card(
                color: const Color(0xFFFFEBEE),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data == null
                            ? t(
                                'Could not load calendar bookings.',
                                'நாட்காட்டி முன்பதிவுகளை ஏற்ற முடியவில்லை.',
                              )
                            : t(
                                'Refresh failed. Showing previous bookings.',
                                'புதுப்பிக்க முடியவில்லை. முந்தைய முன்பதிவுகள் காட்டப்படுகின்றன.',
                              ),
                      ),
                      TextButton(
                        onPressed: load,
                        child: Text(
                          t('Retry', 'மீண்டும் முயற்சி'),
                          style: const TextStyle(
                            color: Color(0xFF80152C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (data != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
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
                child: BookingMonthCalendar(
                  compact: true,
                  bookings: scoped,
                  focusedMonth: month,
                  selectedDay: selected,
                  onMonthChanged: (d) {
                    if (d.year >= 2026 && d.year <= unlockedCalendarYear()) {
                      setState(() => month = d);
                    }
                  },
                  onDaySelected: (d) {
                    if (d.year >= 2026 && d.year <= unlockedCalendarYear()) {
                      setState(() => selected = d);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              Container(
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          bookingDate(context, selected),
                          style: const TextStyle(
                            color: Color(0xFF80152C),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5E8EC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${selectedRows.length} ${t('bookings', 'முன்பதிவுகள்')}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF80152C),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (selectedRows.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                          child: Text(
                            t(
                              'No bookings on this day',
                              'இந்த நாளில் முன்பதிவுகள் இல்லை',
                            ),
                            style: const TextStyle(
                              color: Color(0xFF73737D),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    for (var i = 0; i < selectedRows.length; i++)
                      BookingHistoryCard(
                        booking: selectedRows[i],
                        busy: opening,
                        last: i == selectedRows.length - 1,
                        onOpen: () => details(selectedRows[i]),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
