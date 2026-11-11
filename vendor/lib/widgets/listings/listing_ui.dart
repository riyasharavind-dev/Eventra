import 'package:eventor_vendor/core/theme/app_icon_colors.dart';

import '../common/app_shimmer.dart';

import 'package:flutter/material.dart';

import '../../models/service_model.dart';
import '../../services/app_settings_controller.dart';

String listingText(BuildContext context, String en) =>
    AppSettingsScope.source(context, en);
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
            ? AppSettingsScope.translate(context, "vendor.active.92340695")
            : AppSettingsScope.translate(context, "vendor.inactive.ac7c949f"),
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
  final double photoAspectRatio;
  final VoidCallback onOpen;
  final ValueChanged<String> onAction;
  const ListingCard({
    super.key,
    required this.service,
    this.businessName,
    this.busy = false,
    this.bookingCount,
    this.rating,
    this.photoAspectRatio = .85,
    required this.onOpen,
    required this.onAction,
  });
  static const grayscale = ColorFilter.matrix(<double>[
    .2126,
    .7152,
    .0722,
    0,
    0,
    .2126,
    .7152,
    .0722,
    0,
    0,
    .2126,
    .7152,
    .0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);
  @override
  Widget build(BuildContext context) {
    String t(String key) => AppSettingsScope.translate(context, key);
    final photo = service.gallery.firstOrNull;
    final card = Semantics(
      label: service.name,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onOpen,
          child: Stack(
            children: [
              // Apply varied pin proportions to loaded photos too, so square
              // uploads do not turn the masonry layout into a uniform grid.
              AspectRatio(
                aspectRatio: photoAspectRatio,
                child: photo == null
                    ? const _PhotoFallback()
                    : Image.network(
                        photo,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (_, error, stack) =>
                            const _PhotoFallback(),
                      ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: PopupMenuButton<String>(
                  enabled: !busy,
                  onSelected: onAction,
                  tooltip: t('vendor.listing_actions.44d28c3a'),
                  style: const ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(Colors.transparent),
                    overlayColor: WidgetStatePropertyAll(Colors.transparent),
                    shadowColor: WidgetStatePropertyAll(Colors.transparent),
                    elevation: WidgetStatePropertyAll(0),
                  ),
                  icon: const Icon(
                    Icons.more_vert,
                    size: 23,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 5)],
                  ),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(t('vendor.edit_service.3b3ed7a7')),
                    ),
                    PopupMenuItem(
                      value: service.isArchived ? 'restore' : 'archive',
                      child: Text(
                        t(
                          service.isArchived
                              ? 'listing.restore'
                              : 'listing.archive',
                        ),
                      ),
                    ),
                    if (!service.isArchived)
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(
                          t(
                            service.isActive
                                ? 'vendor.deactivate.fb1e6fa5'
                                : 'vendor.activate.24433c70',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    key: ValueKey('price-${service.id}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFCD45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          label: service.isArchived
                              ? t('listing.archived')
                              : t(
                                  service.isActive
                                      ? 'vendor.active.92340695'
                                      : 'vendor.inactive.ac7c949f',
                                ),
                          child: Container(
                            key: ValueKey('status-${service.id}'),
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: service.isActive && !service.isArchived
                                  ? const Color(0xFF008754)
                                  : const Color(0xFF77777D),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            service.pricing.format(
                              service.price,
                              translate: (value) =>
                                  AppSettingsScope.source(context, value),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4A3000),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (busy)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ShimmerLoadingBar(minHeight: 2),
                ),
            ],
          ),
        ),
      ),
    );
    return service.isArchived
        ? ColorFiltered(colorFilter: grayscale, child: card)
        : card;
  }
}
