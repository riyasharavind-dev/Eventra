import 'package:flutter/material.dart';

import '../../models/booking_model.dart';
import '../../repositories/booking_repository.dart';
import '../../services/app_settings_controller.dart';

String bookingText(BuildContext c, String en, String ta) =>
    AppSettingsScope.of(c).text(en, ta);
String bookingStatus(BuildContext c, String status) {
  const tamil = {
    'pending': 'நிலுவையில்',
    'accepted': 'ஏற்கப்பட்டது',
    'rejected': 'நிராகரிக்கப்பட்டது',
    'completed': 'முடிந்தது',
    'cancelled': 'ரத்து செய்யப்பட்டது',
  };
  return bookingText(
    c,
    status.isEmpty
        ? 'Unknown'
        : '${status[0].toUpperCase()}${status.substring(1)}',
    tamil[status] ?? status,
  );
}

String bookingDate(BuildContext c, DateTime? date) => date == null
    ? bookingText(c, 'Not specified', 'குறிப்பிடப்படவில்லை')
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
        borderRadius: BorderRadius.circular(8),
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

Future<bool> confirmBookingChange(
  BuildContext context,
  BookingRepository repo,
  BookingModel booking,
  String status,
) async {
  try {
    final overlaps = status == 'accepted'
        ? await repo.conflicts(booking.id)
        : <Map<String, dynamic>>[];
    if (!context.mounted) {
      return false;
    }
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => _BookingActionDialog(
        booking: booking,
        status: status,
        conflicts: overlaps,
      ),
    );
    if (reason == null || !context.mounted) {
      return false;
    }
    await repo.updateBookingStatus(
      bookingId: booking.id,
      vendorId: booking.vendorId,
      status: status,
      expectedStatus: booking.status,
      reason: reason.isEmpty ? null : reason,
      acknowledgeOverlap: overlaps.isNotEmpty,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            bookingText(
              context,
              'Booking updated.',
              'முன்பதிவு புதுப்பிக்கப்பட்டது.',
            ),
          ),
        ),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      bookingError(context, e);
    }
    return false;
  }
}

class _BookingActionDialog extends StatefulWidget {
  final BookingModel booking;
  final String status;
  final List<Map<String, dynamic>> conflicts;
  const _BookingActionDialog({
    required this.booking,
    required this.status,
    required this.conflicts,
  });
  @override
  State<_BookingActionDialog> createState() => _BookingActionDialogState();
}

class _BookingActionDialogState extends State<_BookingActionDialog> {
  final form = GlobalKey<FormState>();
  String reason = '';
  @override
  Widget build(BuildContext context) {
    final needsReason = ['rejected', 'cancelled'].contains(widget.status);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        switch (widget.status) {
          'accepted' => bookingText(
            context,
            'Accept booking?',
            'முன்பதிவை ஏற்கவா?',
          ),
          'rejected' => bookingText(
            context,
            'Reject booking?',
            'முன்பதிவை நிராகரிக்கவா?',
          ),
          'completed' => bookingText(
            context,
            'Mark as completed?',
            'முடிந்ததாகக் குறிக்கவா?',
          ),
          _ => bookingText(
            context,
            'Cancel booking?',
            'முன்பதிவை ரத்து செய்யவா?',
          ),
        },
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.booking.customerName}\n${bookingSchedule(context, widget.booking)}',
              ),
              if (widget.conflicts.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  bookingText(
                    context,
                    'Another accepted event may overlap.',
                    'ஏற்கப்பட்ட மற்றொரு நிகழ்வுடன் நேரம் மோதலாம்.',
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ...widget.conflicts.map(
                  (x) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '#${shortBookingId(x['id'].toString())} · ${x['service_name']} · ${x['event_date']}',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  bookingText(
                    context,
                    'If exact times are missing, this warning uses event dates. Accept only if your team can handle both events.',
                    'சரியான நேரம் இல்லையெனில் நிகழ்வு தேதிகளின் அடிப்படையில் எச்சரிக்கை காட்டப்படும். உங்கள் குழுவால் இரண்டையும் செய்ய முடிந்தால் ஏற்கலாம்.',
                  ),
                ),
              ],
              if (needsReason) ...[
                const SizedBox(height: 16),
                TextFormField(
                  maxLines: 3,
                  maxLength: 1000,
                  onChanged: (v) => reason = v,
                  decoration: InputDecoration(
                    labelText: bookingText(
                      context,
                      'Reason (shared with customer)',
                      'காரணம் (வாடிக்கையாளருக்கும் தெரியும்)',
                    ),
                  ),
                  validator: (v) => (v?.trim().length ?? 0) < 3
                      ? bookingText(
                          context,
                          'Enter at least 3 characters',
                          'குறைந்தது 3 எழுத்துகள் உள்ளிடவும்',
                        )
                      : null,
                ),
              ],
              if (widget.status == 'completed')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    bookingText(
                      context,
                      'Confirm that the booked service has been delivered.',
                      'முன்பதிவு செய்யப்பட்ட சேவை வழங்கப்பட்டதை உறுதிப்படுத்தவும்.',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF73737D)),
          onPressed: () => Navigator.pop(context),
          child: Text(bookingText(context, 'Back', 'பின்செல்')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF80152C),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(context, reason.trim());
            }
          },
          child: Text(bookingText(context, 'Confirm', 'உறுதிப்படுத்து')),
        ),
      ],
    );
  }
}
