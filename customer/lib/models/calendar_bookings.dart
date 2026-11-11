import 'booking_model.dart';

DateTime calendarDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);
DateTime calendarEndDay(BookingModel b) {
  final first = calendarDay(b.eventDate),
      last = calendarDay(b.eventEndDate ?? b.eventDate);
  return last.isAfter(first) &&
          RegExp(r'^00:00(?::00(?:\.0+)?)?$').hasMatch(b.eventEndTime ?? '')
      ? last.subtract(const Duration(days: 1))
      : last;
}

bool bookingOccursOn(BookingModel b, DateTime date) {
  final day = calendarDay(date);
  return !day.isBefore(calendarDay(b.eventDate)) &&
      !day.isAfter(calendarEndDay(b));
}

List<BookingModel> bookingsOnDay(List<BookingModel> rows, DateTime date) =>
    rows.where((b) => bookingOccursOn(b, date)).toList()..sort((a, b) {
      final time = (a.eventStartTime ?? '99:99').compareTo(
        b.eventStartTime ?? '99:99',
      );
      return time == 0 ? a.id.compareTo(b.id) : time;
    });
