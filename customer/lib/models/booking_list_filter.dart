import 'booking_model.dart';

List<BookingModel> filterCustomerBookings(
  List<BookingModel> bookings, {
  String query = '',
  String status = 'all',
}) {
  final search = query.trim().toLowerCase();
  return bookings
      .where(
        (b) =>
            (status == 'all' || b.status == status) &&
            (search.isEmpty ||
                [
                  b.id,
                  b.serviceName,
                  b.vendorName,
                  b.location,
                  b.eventTypeName ?? '',
                ].any((s) => s.toLowerCase().contains(search))),
      )
      .toList()
    ..sort((a, b) {
      final created = (b.createdAt ?? b.eventDate).compareTo(
        a.createdAt ?? a.eventDate,
      );
      return created == 0 ? a.id.compareTo(b.id) : created;
    });
}
