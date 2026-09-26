import 'package:flutter/material.dart';

import '../../models/booking_model.dart';

class BookingDetailsDialog extends StatelessWidget {
  final BookingModel booking;

  const BookingDetailsDialog({
    super.key,
    required this.booking,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(
            Icons.calendar_month_outlined,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Booking Details',
            ),
          ),
          _StatusBadge(
            status: booking.status,
          ),
        ],
      ),

      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                title: 'Service',
              ),

              _InfoRow(
                label: 'Service',
                value: booking.serviceName,
              ),

              if (booking.eventTypeName != null)
                _InfoRow(
                  label: 'Event Type',
                  value:
                      booking.eventTypeName!,
                ),

              _InfoRow(
                label: 'Price',
                value:
                    '₹${booking.price.toStringAsFixed(2)}',
              ),

              const SizedBox(height: 20),

              _SectionTitle(
                title: 'Customer',
              ),

              _InfoRow(
                label: 'Name',
                value:
                    booking.customerName,
              ),

              _InfoRow(
                label: 'Email',
                value:
                    booking.customerEmail,
              ),

              const SizedBox(height: 20),

              _SectionTitle(
                title: 'Event',
              ),

              _InfoRow(
                label: 'Date',
                value:
                    _formatDate(
                      booking.eventDate,
                    ),
              ),

              _InfoRow(
                label: 'Guests',
                value:
                    booking.guestCount
                            ?.toString() ??
                        'Not specified',
              ),

              _InfoRow(
                label: 'Location',
                value:
                    booking.location,
              ),

              if (booking.requirement != null &&
                  booking
                      .requirement!
                      .trim()
                      .isNotEmpty) ...[
                const SizedBox(height: 10),

                _InfoRow(
                  label: 'Requirement',
                  value:
                      booking.requirement!,
                ),
              ],

              const SizedBox(height: 20),

              _SectionTitle(
                title: 'Booking',
              ),

              _InfoRow(
                label: 'Booking ID',
                value: booking.id,
              ),

              _InfoRow(
                label: 'Created',
                value:
                    _formatDateTime(
                      booking.createdAt,
                    ),
              ),
            ],
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text(
            'Close',
          ),
        ),
      ],
    );
  }

  String _formatDate(
    DateTime? date,
  ) {
    if (date == null) {
      return 'Not specified';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatDateTime(
    DateTime? date,
  ) {
    if (date == null) {
      return 'Unknown';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}

// =================================================================
// SECTION TITLE
// =================================================================

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// =================================================================
// INFO ROW
// =================================================================

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// STATUS BADGE
// =================================================================

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;

    switch (status) {
      case 'accepted':
        color = Colors.green;
        break;

      case 'rejected':
        color = Colors.red;
        break;

      case 'completed':
        color = Colors.blue;
        break;

      case 'cancelled':
        color = Colors.grey;
        break;

      default:
        color = Colors.orange;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.10,
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight:
              FontWeight.w700,
        ),
      ),
    );
  }
}