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

class _EventorCalendarState extends State<EventorCalendar> {
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
      loading = true;
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
      backgroundColor: const Color(0xFFFCF8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCF8FA),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 40,
      ),
      body: AppShimmerRefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (loading) const ShimmerLoadingBar(),
            if (error != null)
              Card(
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
                        child: Text(t('Retry', 'மீண்டும் முயற்சி')),
                      ),
                    ],
                  ),
                ),
              ),
            if (data != null) ...[
              BookingMonthCalendar(
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
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 1, color: Color(0xFFEDE8EC)),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDFE),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        Text(
                          bookingDate(context, selected),
                          style: const TextStyle(
                            color: Color(0xFF850E2B),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${selectedRows.length} ${t('bookings', 'முன்பதிவுகள்')}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (selectedRows.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                          child: Text(
                            t('History', 'வரலாறு'),
                            style: const TextStyle(
                              color: Color(0xFF8D90A1),
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
