import 'package:eventor_vendor/core/theme/app_icon_colors.dart';

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
    const muted = Color(0xFF73737D);
    const ink = Color(0xFF17171B);
    const wine = Color(0xFF80152C);
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
          Icon(icon, size: 14, color: AppIconColors.standard),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: muted, height: 1.3),
            ),
          ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0EDF0)),
        boxShadow: [
          BoxShadow(
            color: wine.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: busy ? null : onOpen,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, size) => Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: listingPhoto(
                          b.serviceGallery.firstOrNull,
                          width: size.maxWidth < 320 ? 86 : 100,
                          height: 114,
                        ),
                      ),
                      const SizedBox(width: 14),
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
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            BookingStatusChip(status: b.status),
                            const SizedBox(height: 3),
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
                            const SizedBox(height: 7),
                            Text(
                              '₹$amount',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: wine,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 32,
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
                            Icons.chevron_right_rounded,
                            size: 24,
                            color: AppIconColors.standard,
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
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onReject,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6F6F7A),
                            side: const BorderSide(color: Color(0xFFD6D6DF)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            bookingText(context, 'Reject', 'நிராகரி'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: onAccept,
                          style: FilledButton.styleFrom(
                            backgroundColor: wine,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            bookingText(context, 'Accept', 'ஏற்கவும்'),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (b.status == 'accepted')
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onComplete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: wine,
                        side: const BorderSide(color: wine),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.task_alt, size: 18),
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
      ),
    );
  }
}
