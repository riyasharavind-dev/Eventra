import 'package:eventor_vendor/core/theme/app_icon_colors.dart';

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

  Widget _fallback() => ColoredBox(
    color: const Color(0xFFF5E8EC),
    child: Center(
      child: Icon(iconFor(item.kind), color: AppIconColors.standard, size: 25),
    ),
  );

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: busy ? null : onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: item.unread ? const Color(0xFFFFF8FA) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: item.unread
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
              SizedBox(
                width: 52,
                height: 52,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: item.thumbnailUrl == null
                      ? _fallback()
                      : Image.network(
                          item.thumbnailUrl!,
                          fit: BoxFit.cover,
                          cacheWidth: 168,
                          cacheHeight: 168,
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                              ? child
                              : const AppShimmer(
                                  child: SkeletonBox(width: 52, height: 52),
                                ),
                          errorBuilder: (_, error, stack) => _fallback(),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: item.unread
                            ? FontWeight.w800
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
                        fontWeight: FontWeight.w500,
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
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: wine,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
