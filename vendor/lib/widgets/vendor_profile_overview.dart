import 'common/app_shimmer.dart';
import 'image_viewer.dart';

import 'package:flutter/material.dart';

import '../models/profile_statistics.dart';
import '../models/vendor_model.dart';
import '../services/app_settings_controller.dart';

class VendorProfileOverview extends StatelessWidget {
  final VendorModel vendor;
  final ProfileStatistics? statistics;

  final bool loading;
  final bool failed;

  final VoidCallback onEdit;
  final VoidCallback onBusiness;
  final VoidCallback onAbout;
  final VoidCallback onEvents;
  final VoidCallback onReviews;
  final VoidCallback onRetry;

  const VendorProfileOverview({
    super.key,
    required this.vendor,
    required this.statistics,
    this.loading = false,
    this.failed = false,
    required this.onEdit,
    required this.onBusiness,
    required this.onAbout,
    required this.onEvents,
    required this.onReviews,
    required this.onRetry,
  });

  static const wine = Color(0xFF80152C);
  static const gold = Color(0xFFFFCB48);

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final colors = Theme.of(context).colorScheme;

    final about = vendor.aboutMe?.trim() ?? '';

    final hasRating =
        statistics != null &&
        statistics!.reviewCount > 0 &&
        statistics!.rating != null;

    final rating = hasRating ? statistics!.rating!.toStringAsFixed(1) : '—';

    Widget stat(String value, String label, VoidCallback tap) {
      return Expanded(
        child: InkWell(
          onTap: loading || statistics == null ? null : tap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: wine,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget actionButton({
      required String label,
      required IconData icon,
      required Color background,
      required Color foreground,
      required VoidCallback onPressed,
    }) {
      return Expanded(
        child: SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 17),
            style: FilledButton.styleFrom(
              backgroundColor: background,
              foregroundColor: foreground,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: wine.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.maxWidth > 450 ? 104.0 : 84.0;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () => ImageViewer.show(
                      context,
                      imageUrl: vendor.profileImageUrl,
                    ),
                    borderRadius: BorderRadius.circular(60),
                    child: SizedBox(
                      width: size + 5,
                      height: size + 9,
                      child: Stack(
                        children: [
                          Container(
                            width: size,
                            height: size,
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: gold,
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child:
                                  vendor.profileImageUrl?.trim().isNotEmpty ==
                                      true
                                  ? Image.network(
                                      vendor.profileImageUrl!,
                                      fit: BoxFit.cover,
                                      gaplessPlayback: true,
                                      errorBuilder: (_, error, stack) =>
                                          _initial(),
                                    )
                                  : _initial(),
                            ),
                          ),
                          if (statistics?.verified == true)
                            Positioned(
                              right: 0,
                              bottom: 1,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: wine,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vendor.name.trim().isEmpty
                              ? settings.text(
                                  'Eventra Vendor',
                                  'Eventra விற்பனையாளர்',
                                )
                              : vendor.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: wine,
                          ),
                        ),
                        const SizedBox(height: 5),
                        GestureDetector(
                          onTap: about.isEmpty ? onEdit : null,
                          child: Text(
                            about.isEmpty
                                ? settings.text(
                                    'Add a short introduction',
                                    'சிறு அறிமுகத்தைச் சேர்க்கவும்',
                                  )
                                : about,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: 0.55),
          ),

          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                stat(
                  loading ? '…' : statistics?.completedEvents.toString() ?? '—',
                  settings.text('Events', 'நிகழ்வுகள்'),
                  onEvents,
                ),
                VerticalDivider(
                  width: 1,
                  indent: 15,
                  endIndent: 15,
                  color: colors.outlineVariant,
                ),
                stat(
                  loading ? '…' : rating,
                  settings.text('Rating', 'மதிப்பீடு'),
                  onReviews,
                ),
                VerticalDivider(
                  width: 1,
                  indent: 15,
                  endIndent: 15,
                  color: colors.outlineVariant,
                ),
                stat(
                  loading ? '…' : statistics?.reviewCount.toString() ?? '—',
                  settings.text('Reviews', 'விமர்சனங்கள்'),
                  onReviews,
                ),
              ],
            ),
          ),

          if (loading) const ShimmerLoadingBar(minHeight: 2, color: wine),

          if (failed)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(
                settings.text(
                  'Unable to load statistics · Retry',
                  'புள்ளிவிவரங்களை ஏற்ற முடியவில்லை · மீண்டும் முயற்சி',
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Both actions are inside the same profile card.
          Row(
            children: [
              actionButton(
                label: settings.text('Edit Profile', 'சுயவிவரம் திருத்து'),
                icon: Icons.edit_outlined,
                background: wine,
                foreground: Colors.white,
                onPressed: onEdit,
              ),
              const SizedBox(width: 10),
              actionButton(
                label: settings.text('My Business', 'எனது வணிகம்'),
                icon: Icons.storefront_outlined,
                background: gold,
                foreground: Colors.white,
                onPressed: onBusiness,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _initial() {
    final name = vendor.name.trim();

    return ColoredBox(
      color: const Color(0xFFF5E8EC),
      child: Center(
        child: Text(
          name.isEmpty ? 'V' : name.characters.first.toUpperCase(),
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: wine,
          ),
        ),
      ),
    );
  }
}
