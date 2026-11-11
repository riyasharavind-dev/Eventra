import 'package:eventor_customer/services/app_settings_controller.dart';

import '../../widgets/vendor_profile_card.dart';

import 'package:flutter/material.dart';

import '../../repositories/recommendation_repository.dart';
import '../../widgets/home_feed_widgets.dart';
import '../../repositories/home_feed_repository.dart';

class RecommendationResultsScreen extends StatefulWidget {
  const RecommendationResultsScreen({
    super.key,
    required this.serviceId,
    this.vendors = false,
  });
  final String? serviceId;
  final bool vendors;
  @override
  State<RecommendationResultsScreen> createState() =>
      _RecommendationResultsScreenState();
}

class _RecommendationResultsScreenState
    extends State<RecommendationResultsScreen> {
  late final controller = RecommendationController(
    repository: RecommendationRepository(),
    serviceId: widget.serviceId,
    vendors: widget.vendors,
  );
  final feedRepo = HomeFeedRepository();
  @override
  void initState() {
    super.initState();
    controller.refresh();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F8FA),
    appBar: AppBar(
      title: Text(
        widget.vendors
            ? 'Related vendors'
            : widget.serviceId == null
            ? 'Recommended for you'
            : 'Related services',
      ),
    ),
    body: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => RefreshIndicator(
        color: const Color(0xFF80152C),
        onRefresh: controller.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final item in controller.items)
                  SizedBox(
                    width: widget.vendors
                        ? vendorProfileCardWidth(context)
                        : feedCardWidth(MediaQuery.sizeOf(context).width - 32),
                    child: widget.vendors
                        ? VendorProfileCard(
                            item: item,
                            onTap: () => openVendorProfileCard(context, item),
                          )
                        : HomeFeedItemCard(
                            item: item,
                            onTap: () =>
                                openHomeFeedItem(context, item, feedRepo),
                          ),
                  ),
              ],
            ),
            if (controller.loading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: LinearProgressIndicator(color: Color(0xFF80152C)),
              ),
            if (controller.error != null)
              TextButton(
                onPressed: controller.loadMore,
                child: Text(
                  AppSettingsScope.translate(
                    context,
                    "customer.unable_to_load_retry.007ee6bc",
                  ),
                ),
              ),
            if (!controller.loading &&
                controller.error == null &&
                controller.hasMore)
              TextButton(
                onPressed: controller.loadMore,
                child: Text(
                  AppSettingsScope.translate(
                    context,
                    "customer.load_more.ac8991ef",
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
