import 'package:flutter/material.dart';

import '../../models/booking_model.dart';
import '../../services/app_settings_controller.dart';
import '../bookings/vendor_booking_card.dart';

/// Uses the production card layout with entirely local sample data and callbacks.
class SampleBookingCard extends StatelessWidget {
  const SampleBookingCard({
    super.key,
    required this.status,
    required this.onOpen,
    required this.onAccept,
    required this.onReject,
    required this.onComplete,
  });
  final String status;
  final VoidCallback onOpen, onAccept, onReject, onComplete;
  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final today = DateUtils.dateOnly(DateTime.now());
    return VendorBookingCard(
      booking: BookingModel(
        id: 'sample-booking',
        customerId: 'sample-customer',
        vendorId: 'sample-vendor',
        serviceId: 'sample-service',
        eventDate: today.add(const Duration(days: 7)),
        eventStartTime: '10:00',
        eventEndTime: '14:00',
        location: settings.text(
          'Sample venue, Chennai',
          'மாதிரி அரங்கம், சென்னை',
        ),
        price: 25000,
        status: status,
        customerName: settings.text('Sample customer', 'மாதிரி வாடிக்கையாளர்'),
        customerEmail: '',
        vendorName: 'Sample business',
        vendorEmail: '',
        serviceName: settings.text(
          'Wedding decoration • Sample',
          'திருமண அலங்காரம் • மாதிரி',
        ),
      ),
      busy: false,
      onOpen: onOpen,
      onAccept: onAccept,
      onReject: onReject,
      onComplete: onComplete,
    );
  }
}
