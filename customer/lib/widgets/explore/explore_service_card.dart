import 'package:flutter/material.dart';

import '../../models/service_model.dart';
import 'explore_categories.dart';

class ExploreServiceCard extends StatelessWidget {
  const ExploreServiceCard({
    super.key,
    required this.service,
    required this.onView,
  });
  final ServiceModel service;
  final VoidCallback onView;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFECECF1)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onView,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1.2,
            child: service.gallery.isEmpty
                ? _placeholder()
                : Image.network(
                    service.gallery.first,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, error, stack) => _placeholder(),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (service.categoryName?.isNotEmpty ?? false) ...[
                  Text(
                    service.categoryName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF73737D),
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
                Text(
                  service.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF282837),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  service.priceLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: exploreWine,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget _placeholder() => const ColoredBox(
    color: Color(0xFFF8F0F3),
    child: Icon(Icons.event_outlined, size: 48, color: exploreWine),
  );
}

class ExploreServiceGrid extends StatelessWidget {
  const ExploreServiceGrid({
    super.key,
    required this.services,
    required this.onOpen,
  });
  final List<ServiceModel> services;
  final ValueChanged<ServiceModel> onOpen;
  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final columns = (constraints.crossAxisExtent / 170).floor().clamp(1, 3);
      return SliverList.builder(
        itemCount: (services.length / columns).ceil(),
        itemBuilder: (context, row) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var column = 0; column < columns; column++) ...[
                if (column > 0) const SizedBox(width: 12),
                Expanded(
                  child: row * columns + column < services.length
                      ? ExploreServiceCard(
                          key: ValueKey(services[row * columns + column].id),
                          service: services[row * columns + column],
                          onView: () =>
                              onOpen(services[row * columns + column]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
