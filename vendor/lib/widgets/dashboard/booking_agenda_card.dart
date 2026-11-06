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
    final b = booking, colors = Theme.of(context).colorScheme;
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  BookingStatusChip(status: b.status),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                b.serviceName,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(b.customerName),
              if (b.businessName != null)
                Text(
                  b.businessName!,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                bookingSchedule(context, b),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (b.eventStartTime == null)
                Text(
                  t('Time not specified', 'நேரம் குறிப்பிடப்படவில்லை'),
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              if (b.location.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  b.location,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ],
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  TextButton(
                    onPressed: busy ? null : onOpen,
                    child: Text(t('View details', 'விவரங்களைப் பார்')),
                  ),
                  if (showMap && (b.location.isNotEmpty || b.latitude != null))
                    TextButton.icon(
                      onPressed: busy ? null : map,
                      icon: const Icon(Icons.map_outlined),
                      label: Text(t('Open Maps', 'வரைபடம் திற')),
                    ),
                ],
              ),
              if (busy)
                const ShimmerLoadingBar()
              else if (b.status == 'pending' &&
                  (onAccept != null || onReject != null))
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (onAccept != null)
                      FilledButton(
                        onPressed: onAccept,
                        child: Text(t('Accept', 'ஏற்கவும்')),
                      ),
                    if (onReject != null)
                      OutlinedButton(
                        onPressed: onReject,
                        child: Text(t('Reject', 'நிராகரி')),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
