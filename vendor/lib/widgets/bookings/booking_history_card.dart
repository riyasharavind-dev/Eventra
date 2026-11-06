import 'package:flutter/material.dart';

import '../../models/booking_model.dart';
import '../dashboard/booking_month_calendar.dart';
import 'booking_ui.dart';

class BookingHistoryCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback onOpen;
  final bool busy, last;
  const BookingHistoryCard({
    super.key,
    required this.booking,
    required this.onOpen,
    this.busy = false,
    this.last = false,
  });
  @override
  Widget build(BuildContext context) {
    final b = booking;
    final color = calendarStatusColor(b.status);
    final time = bookingTime(context, b.eventStartTime);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 16,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: 0,
                  bottom: last ? null : 0,
                  height: last ? 26 : null,
                  child: Container(width: 1.5, color: const Color(0xFFDBE2E5)),
                ),
                Positioned(
                  top: 22,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 62,
            child: Padding(
              padding: const EdgeInsets.only(top: 20, right: 6),
              child: Text(
                time.isEmpty
                    ? bookingText(context, 'No time', 'நேரம் இல்லை')
                    : time,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: busy ? null : onOpen,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: SizedBox(
                            width: 52,
                            height: 64,
                            child: b.serviceGallery.isEmpty
                                ? const ColoredBox(
                                    color: Color(0xFFF8EDF0),
                                    child: Icon(
                                      Icons.event_outlined,
                                      color: Color(0xFF850E2B),
                                    ),
                                  )
                                : Image.network(
                                    b.serviceGallery.first,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                    errorBuilder: (_, error, stack) =>
                                        const Icon(Icons.image_outlined),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.serviceName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                b.customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                              if (b.location.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '⌖ ${b.location}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF777783),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 6),
                              BookingStatusChip(status: b.status),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 18),
                          child: Icon(Icons.chevron_right, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
