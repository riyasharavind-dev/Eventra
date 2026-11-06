import 'package:flutter/material.dart';

import '../../models/booking_model.dart';
import '../../models/calendar_bookings.dart';
import '../bookings/booking_ui.dart';
import 'booking_month_calendar.dart';

int unlockedCalendarYear() =>
    DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30)).year;

class MinimalBookingCalendar extends StatelessWidget {
  final List<BookingModel> bookings;
  final DateTime focusedMonth, selectedDay;
  final ValueChanged<DateTime> onMonthChanged, onDaySelected;
  const MinimalBookingCalendar({
    super.key,
    required this.bookings,
    required this.focusedMonth,
    required this.selectedDay,
    required this.onMonthChanged,
    required this.onDaySelected,
  });
  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF222436),
        muted = Color(0xFF8D90A1),
        wine = Color(0xFF900C30);
    final locale = MaterialLocalizations.of(context);
    final first = DateTime(focusedMonth.year, focusedMonth.month);
    final last = DateTime(first.year, first.month + 1, 0);
    final offset = (first.weekday % 7 - locale.firstDayOfWeekIndex + 7) % 7;
    final cells = ((offset + last.day) / 7).ceil() * 7;
    final maxYear = unlockedCalendarYear();
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: bookingText(context, 'Previous month', 'முந்தைய மாதம்'),
              onPressed: first.year == 2026 && first.month == 1
                  ? null
                  : () => onMonthChanged(DateTime(first.year, first.month - 1)),
              icon: const Icon(Icons.chevron_left, size: 20, color: muted),
            ),
            Expanded(
              child: Text(
                locale.formatMonthYear(first),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: bookingText(context, 'Next month', 'அடுத்த மாதம்'),
              onPressed: first.year >= maxYear && first.month == 12
                  ? null
                  : () => onMonthChanged(DateTime(first.year, first.month + 1)),
              icon: const Icon(Icons.chevron_right, size: 20, color: muted),
            ),
          ],
        ),
        Row(
          children: List.generate(
            7,
            (i) => Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    [
                      'Sun',
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                    ][(locale.firstDayOfWeekIndex + i) % 7],
                    style: const TextStyle(fontSize: 11, color: muted),
                  ),
                ),
              ),
            ),
          ),
        ),
        for (var week = 0; week < cells ~/ 7; week++)
          Row(
            children: List.generate(7, (column) {
              final number = week * 7 + column - offset + 1;
              if (number < 1 || number > last.day) {
                return const Expanded(child: SizedBox(height: 51));
              }
              final date = DateTime(first.year, first.month, number);
              final selected = calendarDay(selectedDay) == date;
              final statuses = bookingsOnDay(
                bookings,
                date,
              ).map((b) => b.status).toSet();
              return Expanded(
                child: Semantics(
                  selected: selected,
                  button: true,
                  label: locale.formatFullDate(date),
                  child: SizedBox(
                    height: 51,
                    child: Center(
                      child: InkResponse(
                        key: ValueKey(
                          'calendar-${date.year}-${date.month}-${date.day}',
                        ),
                        onTap: () => onDaySelected(date),
                        radius: 23,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected ? wine : Colors.transparent,
                              ),
                              child: Text(
                                '$number',
                                style: TextStyle(
                                  color: selected ? Colors.white : ink,
                                  fontSize: 12,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 6,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final status in statuses)
                                    Container(
                                      width: 4,
                                      height: 4,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: calendarStatusColor(status),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }
}
