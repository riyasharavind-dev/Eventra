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
                    c.serviceId != null
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
                    c.serviceId != null
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
                height:
                    300 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 3),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: c.items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = c.items[index];
                    return SizedBox(
                      width: 180,
                      child: HomeFeedItemCard(
                        item: item,
                        onTap: () {
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
                  label: const Text('Recommendations unavailable. Retry'),
                ),
              ),
            if (!c.loading && c.error == null && c.hasMore)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextButton(
                  onPressed: c.loadMore,
                  child: const Text('Discover more'),
                ),
              ),
          ],
        ),
      );
    },
  );
}
