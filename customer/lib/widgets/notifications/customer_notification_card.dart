import 'package:flutter/material.dart';

import '../../core/theme/app_icon_colors.dart';
import '../../models/booking_model.dart';
import '../bookings/completion_confirmation_button.dart';

class CustomerNotificationCard extends StatelessWidget {
  const CustomerNotificationCard({
    super.key,
    required this.booking,
    required this.timeLabel,
    required this.unread,
    required this.onTap,
    this.onConfirmed,
  });
  final BookingModel booking;
  final String timeLabel;
  final bool unread;
  final VoidCallback onTap;
  final VoidCallback? onConfirmed;
  static const wine = Color(0xFF80152C);

  @override
  Widget build(BuildContext context) {
    final status = booking.status.toLowerCase();
    final title = booking.awaitingCompletion
        ? 'Confirm Event Completion'
        : switch (status) {
            'accepted' || 'confirmed' => 'Booking Confirmed!',
            'completed' => 'Booking Completed!',
            'cancelled' || 'canceled' => 'Booking Cancelled',
            'rejected' => 'Booking Declined',
            'in_progress' => 'Service Update',
            _ => 'Booking Requested',
          };
    final message = booking.awaitingCompletion
        ? '${booking.vendorName} marked ${booking.serviceName} as finished. Please acknowledge completion.'
        : switch (status) {
            'accepted' || 'confirmed' =>
              'Your booking for ${booking.serviceName} with ${booking.vendorName} is confirmed.',
            'completed' => 'Your ${booking.serviceName} booking is completed.',
            'cancelled' || 'canceled' =>
              'Your ${booking.serviceName} booking has been cancelled.',
            'rejected' =>
              '${booking.vendorName} could not accept your ${booking.serviceName} booking.',
            'in_progress' =>
              'Your ${booking.serviceName} service is now in progress.',
            _ =>
              'Your request for ${booking.serviceName} is waiting for confirmation.',
          };
    final green = status == 'completed' || status == 'in_progress';
    final color = green ? const Color(0xFF2E7D32) : wine;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: unread ? const Color(0xFFFFF8FA) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: unread
                    ? const Color(0xFFF2D1DC)
                    : const Color(0xFFF0EDF0),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF80152C).withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: green
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFF5E8EC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    green
                        ? Icons.task_alt_rounded
                        : Icons.calendar_month_outlined,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              unread ? FontWeight.w800 : FontWeight.w700,
                          color: const Color(0xFF17171B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Color(0xFF73737D),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        timeLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF938B92),
                        ),
                      ),
                      if (booking.awaitingCompletion)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: CompletionConfirmationButton(
                            bookingId: booking.id,
                            onConfirmed: onConfirmed,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (unread)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: const BoxDecoration(
                          color: wine,
                          shape: BoxShape.circle,
                        ),
                      ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppIconColors.standard,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
