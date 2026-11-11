import 'package:eventor_customer/services/app_settings_controller.dart';

import '../vendor_profile_card.dart';
import '../../repositories/home_feed_repository.dart';
import '../../screens/extended/recommendation_results_screen.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/service_model.dart';
import '../../repositories/recommendation_repository.dart';
import '../../screens/extended/service_details_screen.dart';
import '../home_feed_widgets.dart';

/// One reusable recommendation shelf for home and service details.
class ServiceRecommendationsSection extends StatefulWidget {
  final RecommendationController controller;
  final bool listenToActivity;
  const ServiceRecommendationsSection({
    super.key,
    required this.controller,
    this.listenToActivity = false,
  });
  @override
  State<ServiceRecommendationsSection> createState() => _SectionState();
}

class _SectionState extends State<ServiceRecommendationsSection> {
  Timer? _refresh;
  @override
  void initState() {
    super.initState();
    if (widget.listenToActivity) {
      RecommendationRepository.changes.addListener(_changed);
    }
  }

  void _changed() {
    _refresh?.cancel();
    _refresh = Timer(
      const Duration(milliseconds: 600),
      widget.controller.refresh,
    );
  }

  @override
  void dispose() {
    _refresh?.cancel();
    if (widget.listenToActivity) {
      RecommendationRepository.changes.removeListener(_changed);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      if (!c.loading && c.error == null && c.items.isEmpty) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.vendors
                        ? 'Related vendors'
                        : c.serviceId != null
                        ? 'Related services'
                        : 'Recommended for you',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF17171B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.vendors
                        ? 'Other vendors offering similar services'
                        : c.serviceId != null
                        ? 'Similar options and more to discover'
                        : c.personalized
                        ? 'Your interests, with something new to explore'
                        : 'Discover services to get started',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF73737D),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (c.items.isNotEmpty)
              SizedBox(
                height: c.vendors
                    ? vendorProfileCardHeight(context) + 8
                    : feedShelfHeight(context),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: c.items.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    if (index == c.items.length) {
                      return FeedSeeAllCard(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => RecommendationResultsScreen(
                              serviceId: c.serviceId,
                              vendors: c.vendors,
                            ),
                          ),
                        ),
                      );
                    }
                    final item = c.items[index];
                    if (c.vendors) {
                      return SizedBox(
                        width: vendorProfileCardWidth(context),
                        child: VendorProfileCard(
                          item: item,
                          onTap: () => openVendorProfileCard(context, item),
                        ),
                      );
                    }
                    return SizedBox(
                      width: feedCardWidth(
                        MediaQuery.sizeOf(context).width - 32,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: HomeFeedItemCard(
                          item: item,
                          onTap: () {
                            if (item.isVendor) {
                              openHomeFeedItem(
                                context,
                                item,
                                HomeFeedRepository(),
                              );
                              return;
                            }
                            if (item.data['service'] is! Map) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => ServiceDetailsScreen(
                                  service: ServiceModel.fromMap(
                                    Map<String, dynamic>.from(
                                      item.data['service'] as Map,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (c.loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(color: Color(0xFF80152C)),
              ),
            if (c.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextButton.icon(
                  onPressed: c.items.isEmpty ? c.refresh : c.loadMore,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    AppSettingsScope.translate(
                      context,
                      "customer.recommendations_unavailable_retry.07e056e2",
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
