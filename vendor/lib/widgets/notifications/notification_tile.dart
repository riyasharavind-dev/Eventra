import '../common/app_shimmer.dart';

import 'package:flutter/material.dart';

import '../../models/vendor_notification.dart';

class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.item,
    required this.onTap,
    this.busy = false,
  });
  final VendorNotification item;
  final VoidCallback onTap;
  final bool busy;
  static const wine = Color(0xFF80152C);
  static IconData iconFor(String kind) => switch (kind) {
    'booking' => Icons.event_available_outlined,
    'payment' => Icons.payments_outlined,
    'review' => Icons.star_outline_rounded,
    'offer' => Icons.local_offer_outlined,
    'support' => Icons.support_agent_outlined,
    _ => Icons.notifications_none_rounded,
  };
  String get timeLabel {
    final age = DateTime.now().difference(item.createdAt);
    if (age.inMinutes < 1) return 'now';
    if (age.inHours < 1) return '${age.inMinutes}m';
    if (age.inDays < 1) return '${age.inHours}h';
    if (age.inDays < 7) return '${age.inDays}d';
    final at = item.createdAt.toLocal();
    return '${at.day}/${at.month}/${at.year}';
  }

  @override
  Widget build(BuildContext context) => Material(
    color: item.unread ? const Color(0xFFFCF3F6) : Colors.white,
    child: InkWell(
      onTap: busy ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFF3E5EA),
              child: Icon(iconFor(item.kind), color: wine, size: 24),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: item.unread
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: const Color(0xFF17171B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFF66636D),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    timeLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF938B92),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (busy)
              const SizedBox(
                width: 14,
                height: 14,
                child: AppShimmerIndicator(strokeWidth: 2),
              )
            else if (item.unread)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: CircleAvatar(radius: 4, backgroundColor: wine),
              ),
          ],
        ),
      ),
    ),
  );
}
