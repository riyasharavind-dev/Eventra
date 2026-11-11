import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:eventor_customer/core/theme/app_icon_colors.dart';
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
                    ? AppSettingsScope.of(context)
                          .text("No time", "நேரம் இல்லை")
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
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF0EDF0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF80152C).withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    onTap: busy ? null : onOpen,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 54,
                              height: 64,
                              child: b.serviceGallery.isEmpty
                                  ? const ColoredBox(
                                      color: Color(0xFFF5E8EC),
                                      child: Icon(
                                        Icons.event_outlined,
                                        color: AppIconColors.standard,
                                      ),
                                    )
                                  : Image.network(
                                      b.serviceGallery.first,
                                      fit: BoxFit.cover,
                                      gaplessPlayback: true,
                                      errorBuilder: (_, error, stack) =>
                                          const ColoredBox(
                                            color: Color(0xFFF5E8EC),
                                            child: Icon(
                                              Icons.image_outlined,
                                              color: AppIconColors.standard,
                                            ),
                                          ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.serviceName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF17171B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  b.vendorName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF73737D),
                                  ),
                                ),
                                if (b.location.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '⌖ ${b.location}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF73737D),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                BookingStatusChip(status: b.status),
                              ],
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(top: 20),
                            child: Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: AppIconColors.standard,
                            ),
                          ),
                        ],
                      ),
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
