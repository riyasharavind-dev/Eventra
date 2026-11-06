import 'package:flutter/material.dart';

import '../../models/booking_model.dart';
import '../../models/calendar_bookings.dart';
import '../dashboard/booking_month_calendar.dart';
import 'booking_ui.dart';

/// Shared month picker and agenda heading; callers supply their booking cards.
class BookingCalendar extends StatelessWidget {
  final List<BookingModel> bookings;
  final DateTime month, selectedDay;
  final ValueChanged<DateTime> onMonthChanged, onDaySelected;
  const BookingCalendar({
    super.key,
    required this.bookings,
    required this.month,
    required this.selectedDay,
    required this.onMonthChanged,
    required this.onDaySelected,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      BookingMonthCalendar(
        bookings: bookings,
        focusedMonth: month,
        selectedDay: selectedDay,
        onMonthChanged: onMonthChanged,
        onDaySelected: onDaySelected,
      ),
      const SizedBox(height: 20),
      Text(
        bookingDate(context, selectedDay),
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        '${bookingsOnDay(bookings, selectedDay).length} ${bookingText(context, 'bookings', 'முன்பதிவுகள்')}',
      ),
      const SizedBox(height: 12),
    ],
  );
}
