import 'package:flutter/material.dart';

import '../../models/booking_model.dart';

class BookingDetailsDialog
    extends StatelessWidget {
  final BookingModel booking;

  const BookingDetailsDialog({
    super.key,
    required this.booking,
  });

  // ============================================================
  // DATE
  // ============================================================

  String _formatDate(
    DateTime? date,
  ) {
    if (date == null) {
      return 'Not available';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  // ============================================================
  // PRICE
  // ============================================================

  String _formatPrice(
    double price,
  ) {
    return '₹${price.toStringAsFixed(0)}';
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color _statusColor(
    String status,
  ) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;

      case 'accepted':
        return Colors.green;

      case 'completed':
        return Colors.blue;

      case 'rejected':
        return Colors.red;

      case 'cancelled':
        return Colors.grey;

      default:
        return Colors.grey;
    }
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget _infoRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 14,
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          SizedBox(
            width: 125,

            child: Text(
              label,

              style:
                  const TextStyle(
                color: Colors.grey,

                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value,

              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final Color statusColor =
        _statusColor(
      booking.status,
    );

    return Dialog(
      insetPadding:
          const EdgeInsets.all(
        20,
      ),

      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),

      child: ConstrainedBox(
        constraints:
            const BoxConstraints(
          maxWidth: 650,
          maxHeight: 750,
        ),

        child: Column(
          children: [
            // ==================================================
            // HEADER
            // ==================================================

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                22,
                18,
                12,
                18,
              ),

              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Booking Details',

                      style:
                          TextStyle(
                        fontSize: 21,

                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                      );
                    },

                    icon:
                        const Icon(
                      Icons.close,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(
              height: 1,
            ),

            // ==================================================
            // CONTENT
            // ==================================================

            Expanded(
              child:
                  SingleChildScrollView(
                padding:
                    const EdgeInsets.all(
                  22,
                ),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    // ==========================================
                    // STATUS
                    // ==========================================

                    Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),

                      decoration:
                          BoxDecoration(
                        color:
                            statusColor
                                .withValues(
                          alpha: 0.10,
                        ),

                        borderRadius:
                            BorderRadius
                                .circular(
                          30,
                        ),
                      ),

                      child: Text(
                        booking.status
                            .toUpperCase(),

                        style:
                            TextStyle(
                          color:
                              statusColor,

                          fontWeight:
                              FontWeight.w800,

                          fontSize: 12,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 24,
                    ),

                    // ==========================================
                    // SERVICE
                    // ==========================================

                    const Text(
                      'Service',

                      style:
                          TextStyle(
                        fontSize: 16,

                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    _infoRow(
                      'Service',
                      booking.serviceName,
                    ),

                    if (booking.eventTypeName !=
                        null)
                      _infoRow(
                        'Event Type',
                        booking
                                .eventTypeName ??
                            '',
                      ),

                    _infoRow(
                      'Price',
                      _formatPrice(
                        booking.price,
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    const Divider(),

                    const SizedBox(
                      height: 18,
                    ),

                    // ==========================================
                    // CUSTOMER
                    // ==========================================

                    const Text(
                      'Customer',

                      style:
                          TextStyle(
                        fontSize: 16,

                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    _infoRow(
                      'Name',
                      booking.customerName,
                    ),

                    _infoRow(
                      'Email',
                      booking.customerEmail,
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    const Divider(),

                    const SizedBox(
                      height: 18,
                    ),

                    // ==========================================
                    // VENDOR
                    // ==========================================

                    const Text(
                      'Vendor',

                      style:
                          TextStyle(
                        fontSize: 16,

                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    _infoRow(
                      'Name',
                      booking.vendorName,
                    ),

                    _infoRow(
                      'Email',
                      booking.vendorEmail,
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    const Divider(),

                    const SizedBox(
                      height: 18,
                    ),

                    // ==========================================
                    // EVENT DETAILS
                    // ==========================================

                    const Text(
                      'Event Details',

                      style:
                          TextStyle(
                        fontSize: 16,

                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    _infoRow(
                      'Event Date',
                      _formatDate(
                        booking.eventDate,
                      ),
                    ),

                    _infoRow(
                      'Guest Count',
                      booking.guestCount
                              ?.toString() ??
                          'Not specified',
                    ),

                    _infoRow(
                      'Location',
                      booking.location,
                    ),

                    if (booking.requirement !=
                            null &&
                        booking.requirement!
                            .trim()
                            .isNotEmpty)
                      _infoRow(
                        'Requirement',
                        booking
                                .requirement ??
                            '',
                      ),

                    const SizedBox(
                      height: 10,
                    ),

                    const Divider(),

                    const SizedBox(
                      height: 18,
                    ),

                    // ==========================================
                    // BOOKING INFORMATION
                    // ==========================================

                    const Text(
                      'Booking Information',

                      style:
                          TextStyle(
                        fontSize: 16,

                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    _infoRow(
                      'Booking ID',
                      booking.id,
                    ),

                    _infoRow(
                      'Created',
                      _formatDate(
                        booking.createdAt,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}