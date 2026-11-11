class BookingDraft {
  const BookingDraft({
    this.quantities = const {},
    required this.date,
    required this.hour,
    required this.minute,
    required this.guests,
    required this.venue,
    required this.requestId,
  });
  final Map<String, int> quantities;
  final DateTime date;
  final int hour, minute, guests;
  final String venue, requestId;
  String get eventTime =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00';
  DateTime get eventDateTime =>
      DateTime(date.year, date.month, date.day, hour, minute);
}
