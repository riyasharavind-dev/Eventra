import 'booking_model.dart';

DateTime bookingDay(DateTime d) => DateTime(d.year, d.month, d.day);

List<BookingModel> filterVendorBookings(
  List<BookingModel> rows, {
  String status = 'all',
  String business = 'all',
  String period = 'all',
  String dateFilter = 'all',
  DateTime? rangeStart,
  DateTime? rangeEnd,
  String query = '',
  String sort = 'event',
  DateTime? now,
}) {
  final today = bookingDay(now ?? DateTime.now());
  DateTime? first, last;
  switch (dateFilter) {
    case 'today':
      first = today;
      last = today;
    case 'week':
      first = today;
      last = today.add(const Duration(days: 6));
    case 'month':
      first = DateTime(today.year, today.month);
      last = DateTime(today.year, today.month + 1, 0);
    case 'custom':
      first = rangeStart;
      last = rangeEnd;
  }
  final search = query.trim().toLowerCase();
  final filtered = rows.where((b) {
    if (status != 'all' && b.status != status) {
      return false;
    }
    if (business != 'all' &&
        (business == 'unassigned'
            ? b.businessId != null
            : b.businessId != business)) {
      return false;
    }
    final start = b.eventDate == null ? null : bookingDay(b.eventDate!);
    final end = b.eventEndDate == null ? start : bookingDay(b.eventEndDate!);
    if (period != 'all' &&
        (end == null ||
            (period == 'upcoming'
                ? end.isBefore(today)
                : !end.isBefore(today)))) {
      return false;
    }
    if (first != null && (end == null || end.isBefore(bookingDay(first)))) {
      return false;
    }
    if (last != null && (start == null || start.isAfter(bookingDay(last)))) {
      return false;
    }
    return search.isEmpty ||
        [
          b.id,
          b.customerName,
          b.customerEmail,
          b.customerPhone ?? '',
          b.serviceName,
          b.location,
          b.businessName ?? '',
          b.eventTypeName ?? '',
        ].any((s) => s.toLowerCase().contains(search));
  }).toList();
  filtered.sort((a, b) {
    int comparison;
    if (sort == 'newest') {
      comparison = (b.createdAt ?? DateTime(1970)).compareTo(
        a.createdAt ?? DateTime(1970),
      );
    } else {
      final ad = a.eventDate, bd = b.eventDate;
      final aPast = (a.eventEndDate ?? ad)?.isBefore(today) ?? false;
      final bPast = (b.eventEndDate ?? bd)?.isBefore(today) ?? false;
      if (ad != null && bd != null && aPast != bPast) {
        return aPast ? 1 : -1;
      }
      comparison = ad == null
          ? (bd == null ? 0 : 1)
          : (bd == null ? -1 : ad.compareTo(bd));
      if (aPast && bPast) {
        comparison = -comparison;
      }
      if (comparison == 0) {
        comparison = (a.eventStartTime ?? '').compareTo(b.eventStartTime ?? '');
      }
    }
    return comparison == 0 ? a.id.compareTo(b.id) : comparison;
  });
  return filtered;
}
