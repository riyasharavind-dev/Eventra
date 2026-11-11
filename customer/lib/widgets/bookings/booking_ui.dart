import 'package:flutter/material.dart';

import '../../models/booking_model.dart';
import '../../services/app_settings_controller.dart';

String bookingText(BuildContext c, String en) => AppSettingsScope.of(c).text(
  en,
  const {
        'Pending': 'நிலுவையில்',
        'Accepted': 'ஏற்கப்பட்டது',
        'Completed': 'முடிந்தது',
        'Rejected': 'நிராகரிக்கப்பட்டது',
        'Cancelled': 'ரத்தானது',
        'All': 'அனைத்தும்',
      }[en] ??
      en,
);
String bookingStatus(BuildContext c, String status) {
  return bookingText(
    c,
    status.isEmpty
        ? 'Unknown'
        : '${status[0].toUpperCase()}${status.substring(1)}',
  );
}

String bookingDate(BuildContext c, DateTime? date) => date == null
    ? AppSettingsScope.of(c).text("Not specified", "குறிப்பிடப்படவில்லை")
    : MaterialLocalizations.of(c).formatMediumDate(date);
String bookingTime(BuildContext c, String? time) {
  final parts = time?.split(':');
  if (parts == null || parts.length < 2) {
    return '';
  }
  final h = int.tryParse(parts[0]), m = int.tryParse(parts[1]);
  if (h == null || m == null) {
    return '';
  }
  return MaterialLocalizations.of(c)
      .formatTimeOfDay(TimeOfDay(hour: h, minute: m));
}

String bookingSchedule(BuildContext c, BookingModel b) {
  final start = bookingTime(c, b.eventStartTime),
      end = bookingTime(c, b.eventEndTime);
  final last = b.eventEndDate;
  final dates = last != null && last != b.eventDate
      ? '${bookingDate(c, b.eventDate)} – ${bookingDate(c, last)}'
      : bookingDate(c, b.eventDate);
  return '$dates${start.isEmpty ? '' : ' · $start${end.isEmpty ? '' : ' – $end'} (${b.eventTimezone})'}';
}

String shortBookingId(String id) =>
    id.length <= 8 ? id.toUpperCase() : id.substring(0, 8).toUpperCase();
void bookingError(BuildContext c, Object error) {
  final message = error.toString().replaceFirst('Bad state: ', '');
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(message)));
}

class BookingStatusChip extends StatelessWidget {
  final String status;
  const BookingStatusChip({super.key, required this.status});
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'accepted' => const Color(0xFF008953),
      'completed' => const Color(0xFF1976D2),
      'rejected' || 'cancelled' => const Color(0xFFC62828),
      _ => const Color(0xFFD97706),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        bookingStatus(context, status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Widget bookingPhoto(String? url, {double? width, double height = 110}) =>
    SizedBox(
      width: width,
      height: height,
      child: url == null || url.isEmpty
          ? const ColoredBox(
              color: Color(0xFFF5E8EC),
              child: Icon(Icons.image_outlined, color: Color(0xFF73737D)),
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, error, stack) => const ColoredBox(
                color: Color(0xFFF5E8EC),
                child: Icon(Icons.image_outlined, color: Color(0xFF73737D)),
              ),
            ),
    );
