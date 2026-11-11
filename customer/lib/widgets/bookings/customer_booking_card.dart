import '../../repositories/booking_repository.dart';
import 'completion_confirmation_button.dart';

import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:eventor_customer/core/theme/app_icon_colors.dart';

import '../common/app_shimmer.dart';

import 'package:flutter/material.dart';

import '../../models/booking_model.dart';
import 'booking_ui.dart';

class CustomerBookingCard extends StatelessWidget {
  final BookingModel booking;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback? onReview, onAcknowledged;
  final BookingRepository? repository;

  const CustomerBookingCard({
    super.key,
    required this.booking,
    required this.busy,
    required this.onOpen,
    this.onReview,
    this.onAcknowledged,
    this.repository,
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
        ? AppSettingsScope.of(context)
              .text("Time not specified", "நேரம் குறிப்பிடப்படவில்லை")
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
                        child: bookingPhoto(
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
                                  ? AppSettingsScope.of(context).text(
                                      "Location not specified",
                                      "இடம் குறிப்பிடப்படவில்லை",
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
                          tooltip: AppSettingsScope.of(context)
                              .text("Open booking", "முன்பதிவைத் திற"),
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
              if (b.awaitingCompletion)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        AppSettingsScope.translate(
                          context,
                          "customer.the_vendor_marked_this_event_as_finished_plea.6f0ade1e",
                        ),
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      CompletionConfirmationButton(
                        bookingId: b.id,
                        repository: repository,
                        onConfirmed: onAcknowledged,
                      ),
                    ],
                  ),
                ),
              if (b.status == 'completed' && onReview != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: FilledButton.icon(
                      onPressed: busy ? null : onReview,
                      icon: const Icon(Icons.rate_review_outlined, size: 17),
                      label: Text(
                        AppSettingsScope.translate(
                          context,
                          "customer.give_a_review.f0a1cf2d",
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: wine,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              if (busy) const ShimmerLoadingBar(minHeight: 2, color: wine),
            ],
          ),
        ),
      ),
    );
  }
}
