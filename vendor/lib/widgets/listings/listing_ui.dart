import 'package:eventor_vendor/core/theme/app_icon_colors.dart';

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
        color: AppIconColors.standard,
      ),
    ),
  );
}

class ListingStatusBadge extends StatelessWidget {
  final bool active;
  const ListingStatusBadge({super.key, required this.active});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF00A86B).withValues(alpha: 0.12)
            : const Color(0xFF6F6F7A).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active
            ? listingText(context, 'Active', 'செயலில்')
            : listingText(context, 'Inactive', 'செயலற்றது'),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: active ? const Color(0xFF00A86B) : const Color(0xFF6F6F7A),
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
    const wine = Color(0xFF80152C);
    const muted = Color(0xFF73737D);
    const darkText = Color(0xFF17171B);

    Widget metric(
      IconData icon,
      String value,
      String hint, {
      Color? iconColor,
    }) => Tooltip(
      message: hint,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor ?? AppIconColors.standard),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: iconColor != null ? darkText : muted,
              ),
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
      icon: const Icon(
        Icons.more_vert,
        size: 20,
        color: AppIconColors.standard,
      ),
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
    return Container(
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
                  builder: (context, size) {
                    final photoWidth = size.maxWidth < 320 ? 86.0 : 102.0;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: listingPhoto(
                            s.gallery.firstOrNull,
                            width: photoWidth,
                            height: 114,
                          ),
                        ),
                        const SizedBox(width: 14),
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
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        s.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: darkText,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: s.isActive
                                          ? const Color(0xFF00A86B)
                                                .withValues(alpha: 0.12)
                                          : const Color(0xFF6F6F7A)
                                                .withValues(alpha: 0.12),
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
                                        fontWeight: FontWeight.w800,
                                        color: s.isActive
                                            ? const Color(0xFF00A86B)
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
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: muted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                s.pricing.format(
                                  s.price,
                                  tamil: AppSettingsScope.of(context).tamil,
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: wine,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 12,
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
                                    Icons.star_rounded,
                                    rating?.toStringAsFixed(1) ?? '—',
                                    listingText(
                                      context,
                                      'Average rating',
                                      'சராசரி மதிப்பீடு',
                                    ),
                                    iconColor: const Color(0xFFD49700),
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
      ),
    );
  }
}
