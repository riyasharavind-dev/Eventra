import '../common/app_shimmer.dart';

import 'package:flutter/material.dart';

import '../../models/service_model.dart';
import '../../services/app_settings_controller.dart';

String listingText(BuildContext context, String en, String ta) =>
    AppSettingsScope.of(context).text(en, ta);
void listingError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        error
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('Bad state: ', ''),
      ),
    ),
  );
}

Widget listingPhoto(String? url, {double? width, double height = 110}) =>
    SizedBox(
      width: width,
      height: height,
      child: url == null || url.isEmpty
          ? const _PhotoFallback()
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stack) => const _PhotoFallback(),
            ),
    );

class _PhotoFallback extends StatelessWidget {
  const _PhotoFallback();
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Center(
      child: Icon(
        Icons.image_outlined,
        size: 32,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class ListingStatusBadge extends StatelessWidget {
  final bool active;
  const ListingStatusBadge({super.key, required this.active});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? colors.primaryContainer
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        active
            ? listingText(context, 'Active', 'செயலில்')
            : listingText(context, 'Inactive', 'செயலற்றது'),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: active ? colors.onPrimaryContainer : colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class ListingCard extends StatelessWidget {
  final ServiceModel service;
  final String? businessName;
  final bool busy;
  final int? bookingCount;
  final double? rating;
  final VoidCallback onOpen;
  final ValueChanged<String> onAction;
  const ListingCard({
    super.key,
    required this.service,
    this.businessName,
    this.busy = false,
    this.bookingCount,
    this.rating,
    required this.onOpen,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final s = service, colors = Theme.of(context).colorScheme;
    const wine = Color(0xFF850E2B), muted = Color(0xFF7B8194);
    Widget metric(IconData icon, String value, String hint) => Tooltip(
      message: hint,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: muted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: muted),
            ),
          ),
        ],
      ),
    );
    final menu = PopupMenuButton<String>(
      enabled: !busy,
      onSelected: onAction,
      tooltip: listingText(context, 'Listing actions', 'பட்டியல் செயல்கள்'),
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF282837)),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'edit',
          child: Text(
            listingText(context, 'Edit service', 'சேவையைத் திருத்து'),
          ),
        ),
        PopupMenuItem(
          value: 'gallery',
          child: Text(
            listingText(context, 'Manage photos', 'புகைப்படங்களை நிர்வகி'),
          ),
        ),
        PopupMenuItem(
          value: 'toggle',
          child: Text(
            s.isActive
                ? listingText(context, 'Deactivate', 'செயலிழக்கச் செய்')
                : listingText(context, 'Activate', 'செயல்படுத்து'),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Text(
            listingText(context, 'Delete', 'நீக்கு'),
            style: TextStyle(color: colors.error),
          ),
        ),
      ],
    );
    return Card(
      color: Colors.white,
      margin: EdgeInsets.zero,
      elevation: 1,
      shadowColor: const Color(0x16000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: const BorderSide(color: Color(0xFFECECF1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onOpen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(9),
              child: LayoutBuilder(
                builder: (context, size) {
                  final photoWidth = size.maxWidth < 320 ? 82.0 : 98.0;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: listingPhoto(
                          s.gallery.firstOrNull,
                          width: photoWidth,
                          height: 112,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text(
                                      s.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF171720),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 78,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: s.isActive
                                        ? const Color(0xFFE5F8EE)
                                        : const Color(0xFFF2F3F6),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    s.isActive
                                        ? listingText(
                                            context,
                                            'Active',
                                            'செயலில்',
                                          )
                                        : listingText(
                                            context,
                                            'Inactive',
                                            'செயலற்றது',
                                          ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: s.isActive
                                          ? const Color(0xFF009E60)
                                          : muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.categoryName ??
                                  businessName ??
                                  listingText(context, 'Service', 'சேவை'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: muted,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              s.pricing.format(
                                s.price,
                                tamil: AppSettingsScope.of(context).tamil,
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF171720),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              children: [
                                metric(
                                  Icons.receipt_long_outlined,
                                  bookingCount?.toString() ?? '—',
                                  listingText(
                                    context,
                                    'Bookings',
                                    'முன்பதிவுகள்',
                                  ),
                                ),
                                metric(
                                  Icons.star_outline_rounded,
                                  rating?.toStringAsFixed(1) ?? '—',
                                  listingText(
                                    context,
                                    'Average rating',
                                    'சராசரி மதிப்பீடு',
                                  ),
                                ),
                                metric(
                                  Icons.calendar_today_outlined,
                                  MaterialLocalizations.of(context)
                                      .formatShortDate(s.createdAt.toLocal()),
                                  listingText(
                                    context,
                                    'Added on',
                                    'சேர்க்கப்பட்ட தேதி',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 28, height: 40, child: menu),
                    ],
                  );
                },
              ),
            ),
            if (busy) const ShimmerLoadingBar(minHeight: 2, color: wine),
          ],
        ),
      ),
    );
  }
}
