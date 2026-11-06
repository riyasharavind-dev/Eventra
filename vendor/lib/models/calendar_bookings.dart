import 'booking_model.dart';

DateTime calendarDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);
DateTime? calendarEndDay(BookingModel b) {
  if (b.eventDate == null) {
    return null;
  }
  final first = calendarDay(b.eventDate!),
      last = calendarDay(b.eventEndDate ?? b.eventDate!);
  if (last.isAfter(first) &&
      RegExp(r'^00:00(?::00(?:\.0+)?)?$').hasMatch(b.eventEndTime ?? '')) {
    return last.subtract(const Duration(days: 1));
  }
  return last;
}

bool bookingMatchesBusiness(BookingModel b, String business) =>
    business == 'all' ||
    (business == 'unassigned'
        ? b.businessId == null
        : b.businessId == business);
bool bookingOccursOn(BookingModel b, DateTime date) {
  if (b.eventDate == null) {
    return false;
  }
  final first = calendarDay(b.eventDate!), last = calendarEndDay(b)!;
  final day = calendarDay(date);
  return !day.isBefore(first) && !day.isAfter(last);
}

List<BookingModel> calendarScope(
  List<BookingModel> rows, {
  String business = 'all',
  String status = 'all',
}) => rows
    .where(
      (b) =>
          bookingMatchesBusiness(b, business) &&
          (status == 'all' || b.status == status),
    )
    .toList();
List<BookingModel> bookingsOnDay(List<BookingModel> rows, DateTime date) =>
    rows.where((b) => bookingOccursOn(b, date)).toList()..sort((a, b) {
      final time = (a.eventStartTime ?? '99:99').compareTo(
        b.eventStartTime ?? '99:99',
      );
      return time == 0 ? a.id.compareTo(b.id) : time;
    });
List<BookingModel> pastCalendarBookings(
  List<BookingModel> rows, {
  DateTime? now,
}) {
  final today = calendarDay(now ?? DateTime.now());
  return rows
      .where((b) => b.eventDate != null && calendarEndDay(b)!.isBefore(today))
      .toList()
    ..sort((a, b) {
      final date = (b.eventEndDate ?? b.eventDate!).compareTo(
        a.eventEndDate ?? a.eventDate!,
      );
      return date == 0 ? a.id.compareTo(b.id) : date;
    });
}

List<BookingModel> upcomingCommitments(
  List<BookingModel> rows, {
  DateTime? now,
}) {
  final today = calendarDay(now ?? DateTime.now());
  return rows
      .where(
        (b) =>
            b.status == 'accepted' &&
            b.eventDate != null &&
            !calendarEndDay(b)!.isBefore(today),
      )
      .toList()
    ..sort((a, b) {
      final date = a.eventDate!.compareTo(b.eventDate!);
      if (date != 0) {
        return date;
      }
      return (a.eventStartTime ?? '').compareTo(b.eventStartTime ?? '');
    });
}
