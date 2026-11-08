import '../common/app_shimmer.dart';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/booking_model.dart';
import '../bookings/booking_ui.dart';

class BookingAgendaCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback onOpen;
  final VoidCallback? onAccept, onReject;
  final bool busy, showMap;
  const BookingAgendaCard({
    super.key,
    required this.booking,
    required this.onOpen,
    this.onAccept,
    this.onReject,
    this.busy = false,
    this.showMap = false,
  });
  @override
  Widget build(BuildContext context) {
    final b = booking;
    String t(String en, String ta) => bookingText(context, en, ta);
    Future<void> map() async {
      final valid =
          b.latitude != null &&
          b.longitude != null &&
          b.latitude!.isFinite &&
          b.longitude!.isFinite &&
          b.latitude!.abs() <= 90 &&
          b.longitude!.abs() <= 180;
      final query = valid ? '${b.latitude},${b.longitude}' : b.location;
      try {
        if (!await launchUrl(
          Uri.https('www.google.com', '/maps/search/', {
            'api': '1',
            'query': query,
          }),
          mode: LaunchMode.externalApplication,
        )) {
          throw StateError(
            t('Could not open Maps.', 'வரைபடத்தைத் திறக்க முடியவில்லை.'),
          );
        }
      } catch (e) {
        if (context.mounted) {
          bookingError(context, e);
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0EDF0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF80152C).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: busy ? null : onOpen,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '#${shortBookingId(b.id)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF73737D),
                      ),
                    ),
                    BookingStatusChip(status: b.status),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  b.serviceName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF17171B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  b.customerName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF73737D),
                  ),
                ),
                if (b.businessName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      b.businessName!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF80152C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  bookingSchedule(context, b),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF17171B),
                  ),
                ),
                if (b.eventStartTime == null)
                  Text(
                    t('Time not specified', 'நேரம் குறிப்பிடப்படவில்லை'),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF73737D),
                    ),
                  ),
                if (b.location.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '📍 ${b.location}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF73737D)),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF80152C),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: busy ? null : onOpen,
                      child: Text(
                        t('View details', 'விவரங்களைப் பார்'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (showMap && (b.location.isNotEmpty || b.latitude != null))
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF80152C),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: busy ? null : map,
                        icon: const Icon(Icons.map_outlined, size: 16),
                        label: Text(t('Open Maps', 'வரைபடம் திற')),
                      ),
                  ],
                ),
                if (busy)
                  const ShimmerLoadingBar()
                else if (b.status == 'pending' &&
                    (onAccept != null || onReject != null)) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (onAccept != null)
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF80152C),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: onAccept,
                          child: Text(
                            t('Accept', 'ஏற்கவும்'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      if (onReject != null)
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFC62828),
                            side: const BorderSide(color: Color(0xFFEF9A9A)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: onReject,
                          child: Text(
                            t('Reject', 'நிராகரி'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
