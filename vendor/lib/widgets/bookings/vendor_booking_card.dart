import '../common/app_shimmer.dart';

import 'package:flutter/material.dart';

import '../../models/booking_model.dart';
import '../listings/listing_ui.dart' show listingPhoto;
import 'booking_ui.dart';

class VendorBookingCard extends StatelessWidget {
  final BookingModel booking;
  final bool busy;
  final VoidCallback onOpen, onAccept, onReject, onComplete;

  const VendorBookingCard({
    super.key,
    required this.booking,
    required this.busy,
    required this.onOpen,
    required this.onAccept,
    required this.onReject,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final b = booking;
    const muted = Color(0xFF7B8194);
    const ink = Color(0xFF171720);
    const wine = Color(0xFF850E2B);
    final start = bookingTime(context, b.eventStartTime);
    final end = bookingTime(context, b.eventEndTime);
    final dates = b.eventEndDate != null && b.eventEndDate != b.eventDate
        ? '${bookingDate(context, b.eventDate)} – ${bookingDate(context, b.eventEndDate)}'
        : bookingDate(context, b.eventDate);
    final time = start.isEmpty
        ? bookingText(
            context,
            'Time not specified',
            'நேரம் குறிப்பிடப்படவில்லை',
          )
        : '$start${end.isEmpty ? '' : ' – $end'}';
    final price = b.price.toStringAsFixed(2).split('.');
    final amount =
        MaterialLocalizations.of(context)
            .formatDecimal(int.parse(price.first)) +
        (price.last == '00' ? '' : '.${price.last}');

    Widget detail(IconData icon, String value) => Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: muted),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: muted),
            ),
          ),
        ],
      ),
    );

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shadowColor: const Color(0x16000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: const BorderSide(color: Color(0xFFECECF1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onOpen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(9),
              child: LayoutBuilder(
                builder: (context, size) => Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: listingPhoto(
                        b.serviceGallery.firstOrNull,
                        width: size.maxWidth < 320 ? 82 : 98,
                        height: 112,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.serviceName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 5),
                          BookingStatusChip(status: b.status),
                          detail(Icons.calendar_today_outlined, dates),
                          detail(Icons.schedule_outlined, time),
                          detail(
                            Icons.location_on_outlined,
                            b.location.trim().isEmpty
                                ? bookingText(
                                    context,
                                    'Location not specified',
                                    'இடம் குறிப்பிடப்படவில்லை',
                                  )
                                : b.location,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '₹$amount',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      height: 48,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: bookingText(
                          context,
                          'Open booking',
                          'முன்பதிவைத் திற',
                        ),
                        onPressed: busy ? null : onOpen,
                        icon: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 18,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (busy)
              const ShimmerLoadingBar(minHeight: 2, color: wine)
            else if (b.status == 'pending')
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 0, 9, 9),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onReject,
                        child: Text(bookingText(context, 'Reject', 'நிராகரி')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: onAccept,
                        child: Text(bookingText(context, 'Accept', 'ஏற்கவும்')),
                      ),
                    ),
                  ],
                ),
              )
            else if (b.status == 'accepted')
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 0, 9, 9),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(Icons.task_alt),
                    label: Text(
                      bookingText(
                        context,
                        'Mark as Completed',
                        'முடிந்ததாகக் குறி',
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
