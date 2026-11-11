import 'package:flutter/material.dart';

import '../core/theme/app_icon_colors.dart';
import '../models/home_feed.dart';
import '../repositories/home_feed_repository.dart';
import '../screens/extended/business_services_screen.dart';
import 'home_feed_widgets.dart';

double vendorProfileCardWidth(BuildContext context) =>
    (MediaQuery.sizeOf(context).width - 40).clamp(280.0, 380.0) * .75;
double _vendorBannerHeight(BuildContext context) =>
    vendorProfileCardWidth(context) * .28;
double vendorProfileCardHeight(BuildContext context) =>
    _vendorBannerHeight(context) +
    73 +
    (MediaQuery.textScalerOf(context).scale(14) / 14 - 1).clamp(0, 4) * 45;
void openVendorProfileCard(BuildContext context, HomeFeedItem item) {
  final businessId = item.data['business_id']?.toString();
  if (businessId?.isNotEmpty == true) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => BusinessServicesScreen(
          businessId: businessId!,
          businessName: item.data['business_name']?.toString() ?? item.name,
        ),
      ),
    );
  } else {
    openHomeFeedItem(context, item, HomeFeedRepository());
  }
}

/// Compact banner profile with readable typography and fixed dimensions.
class VendorProfileCard extends StatelessWidget {
  const VendorProfileCard({super.key, required this.item, required this.onTap});
  final HomeFeedItem item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final logo = item.data['business_logo_url']?.toString().trim();
    final banner = item.data['business_banner_url']?.toString().trim();
    final name = item.data['business_name']?.toString().trim();
    final description = item.data['business_description']?.toString().trim();
    final location = item.data['location']?.toString().trim();
    final category = item.data['parent_category']?.toString().trim();
    final imageHeight = _vendorBannerHeight(context);
    Widget missing(IconData icon) => ColoredBox(
      color: const Color(0xFFF5E8EC),
      child: Center(
        child: Icon(icon, color: const Color(0xFF80152C), size: 24),
      ),
    );
    return Container(
      height: vendorProfileCardHeight(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0EDF0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF80152C).withValues(alpha: .05),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: imageHeight + 6,
                child: banner?.isNotEmpty == true
                    ? Image.network(
                        banner!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            missing(Icons.panorama_outlined),
                      )
                    : missing(Icons.panorama_outlined),
              ),
              Positioned(
                top: imageHeight - 4,
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: imageHeight - 26,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xCC17171B),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFCB48),
                        size: 14,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${item.rating == null || item.rating == 0 ? '0' : item.rating!.toStringAsFixed(1)} (${item.data['review_count'] ?? 0})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: imageHeight - 16,
                left: 9,
                child: Container(
                  width: 50,
                  height: 54,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF0EDF0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .06),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: logo?.isNotEmpty == true
                        ? Image.network(
                            logo!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                missing(Icons.storefront_outlined),
                          )
                        : missing(Icons.storefront_outlined),
                  ),
                ),
              ),
              Positioned(
                top: imageHeight + 3,
                left: 68,
                right: 9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name?.isNotEmpty == true ? name! : item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF17171B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description?.isNotEmpty == true
                          ? description!
                          : 'Event services',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.15,
                        color: Color(0xFF73737D),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 10,
                left: 9,
                right: 9,
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: _ProfileFact(
                        icon: Icons.location_on_outlined,
                        label: location?.isNotEmpty == true
                            ? location!
                            : 'Not specified',
                      ),
                    ),
                    const _ProfileDivider(),
                    Expanded(
                      flex: 4,
                      child: _ProfileFact(
                        icon: Icons.calendar_month_outlined,
                        label: item.data['since_year'] == null
                            ? 'Since —'
                            : 'Since ${item.data['since_year']}',
                      ),
                    ),
                    const _ProfileDivider(),
                    Expanded(
                      flex: 4,
                      child: _ProfileFact(
                        icon: Icons.category_outlined,
                        label: category?.isNotEmpty == true
                            ? category!
                            : 'Services',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileFact extends StatelessWidget {
  const _ProfileFact({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Row(
      children: [
        Icon(icon, size: 13, color: AppIconColors.standard),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF73737D)),
          ),
        ),
      ],
    ),
  );
}

class _ProfileDivider extends StatelessWidget {
  const _ProfileDivider();
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 14,
    color: const Color(0xFFF0EDF0),
    margin: const EdgeInsets.symmetric(horizontal: 4),
  );
}
