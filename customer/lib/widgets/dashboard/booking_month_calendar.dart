import 'package:flutter/material.dart';

import '../../models/booking_model.dart';
import 'minimal_booking_calendar.dart';

Color calendarStatusColor(String status) => switch (status) {
  'accepted' => const Color(0xFF22844F),
  'completed' => const Color(0xFF216AB0),
  'rejected' => const Color(0xFFC62828),
  'cancelled' => const Color(0xFF757575),
  _ => const Color(0xFFBF7600),
};

class BookingMonthCalendar extends StatelessWidget {
  const BookingMonthCalendar({
    super.key,
    required this.bookings,
    required this.focusedMonth,
    required this.selectedDay,
    required this.onMonthChanged,
    required this.onDaySelected,
  });
  final List<BookingModel> bookings;
  final DateTime focusedMonth, selectedDay;
  final ValueChanged<DateTime> onMonthChanged, onDaySelected;
  @override
  Widget build(BuildContext context) => MinimalBookingCalendar(
    bookings: bookings,
    focusedMonth: focusedMonth,
    selectedDay: selectedDay,
    onMonthChanged: onMonthChanged,
    onDaySelected: onDaySelected,
  );
}
