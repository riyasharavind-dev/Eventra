import 'package:flutter/material.dart';

import '../models/vendor_notification.dart';
import '../repositories/booking_repository.dart';
import '../repositories/business_repository.dart';
import '../repositories/support_repository.dart';
import '../screens/extended/booking_details_screen.dart';
import '../screens/extended/service_reviews_screen.dart';
import '../screens/extended/business_details.dart';
import '../screens/extended/help_support_screen.dart';

Future<void> openVendorNotification(
  BuildContext context,
  VendorNotification item,
) async {
  final target = item.targetId;
  switch (item.targetType) {
    case 'booking':
      if (target == null) break;
      final booking = await BookingRepository().getBooking(target);
      if (!context.mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => BookingDetailsScreen(booking: booking),
        ),
      );
      return;
    case 'review':
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ServiceReviewsScreen(serviceId: target, vendorMode: true),
        ),
      );
      return;
    case 'verification':
      // Existing notifications remain readable without a document upload route.
      break;
    case 'business':
      if (target == null) break;
      final business = await BusinessRepository().getBusinessById(target);
      if (!context.mounted) return;
      if (business == null) throw StateError('Unavailable');
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => BusinessSingleDetailsScreen(business: business),
        ),
      );
      return;
    case 'support':
      if (target == null) break;
      final repo = SupportRepository();
      final tickets = await repo.getTickets(ticketId: target);
      if (!context.mounted) return;
      if (tickets.isEmpty) throw StateError('Unavailable');
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => SupportRequestDetailScreen(
            ticket: tickets.first,
            repository: repo,
          ),
        ),
      );
      return;
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.title,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Text(item.body, style: const TextStyle(height: 1.6, fontSize: 15)),
            if (item.data['reference'] is String &&
                (item.data['reference'] as String).isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Reference: ${item.data['reference']}'),
            ],
          ],
        ),
      ),
    ),
  );
}
