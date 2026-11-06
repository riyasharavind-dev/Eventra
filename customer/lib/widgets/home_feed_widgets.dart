import 'package:flutter/material.dart';

import '../models/home_feed.dart';
import '../models/service_model.dart';
import '../repositories/home_feed_repository.dart';
import '../screens/extended/service_details_screen.dart';

void openHomeFeedItem(
  BuildContext context,
  HomeFeedItem item,
  HomeFeedRepository repo,
) {
  if (item.isVendor) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HomeFeedResultsScreen(
          title: item.name,
          vendor: item,
          repository: repo,
        ),
      ),
    );
  } else if (item.data['service'] is Map) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServiceDetailsScreen(
          service: ServiceModel.fromMap(
            Map<String, dynamic>.from(item.data['service'] as Map),
          ),
        ),
      ),
    );
  }
}

class HomeFeedItemCard extends StatelessWidget {
  final HomeFeedItem item;
  final VoidCallback onTap;
  const HomeFeedItemCard({super.key, required this.item, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 112,
            width: double.infinity,
            child: item.image?.isNotEmpty == true
                ? Image.network(
                    item.image!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stack) =>
                        const Icon(Icons.image_outlined, color: Colors.grey),
                  )
                : Icon(
                    item.isVendor
                        ? Icons.storefront_outlined
                        : Icons.event_outlined,
                    color: Colors.grey,
                    size: 40,
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.isVendor
                      ? '${item.data['completed_count'] ?? 0} completed events'
                      : '₹${item.price.toStringAsFixed(item.price % 1 == 0 ? 0 : 2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF920D29),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.rating == null
                      ? 'New on Eventra'
                      : '★ ${item.rating!.toStringAsFixed(1)} · ${item.data['review_count']} reviews',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF73737D),
                  ),
                ),
                if (item.data['distance_km'] != null)
                  Text(
                    '${item.data['distance_km']} km away',
                    style: const TextStyle(fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class HomeFeedSliver extends StatelessWidget {
  final HomeFeedController controller;
  const HomeFeedSliver({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index == controller.sections.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: controller.loading
                ? const Center(child: CircularProgressIndicator())
                : controller.error != null
                ? TextButton(
                    onPressed: controller.loadMore,
                    child: const Text('Unable to load feed. Retry'),
                  )
                : controller.hasMore
                ? TextButton(
                    onPressed: controller.loadMore,
                    child: const Text('Load more'),
                  )
                : const SizedBox.shrink(),
          );
        }
        final section = controller.sections[index];
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        section.title,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HomeFeedResultsScreen(
                            title: section.title,
                            sectionId: section.id,
                            repository: controller.repository,
                            lat: controller.lat,
                            lng: controller.lng,
                          ),
                        ),
                      ),
                      child: const Text('See All'),
                    ),
                  ],
                ),
              ),
              if (section.layout == 'grid')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final item in section.items)
                        SizedBox(
                          width: (MediaQuery.sizeOf(context).width - 44) / 2,
                          child: HomeFeedItemCard(
                            item: item,
                            onTap: () => openHomeFeedItem(
                              context,
                              item,
                              controller.repository,
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              else
                SizedBox(
                  height:
                      242 +
                      (MediaQuery.textScalerOf(context).scale(14) - 14).clamp(
                            0,
                            42,
                          ) *
                          7,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: section.items.length,
                    separatorBuilder: (_, index) => const SizedBox(width: 12),
                    itemBuilder: (context, i) => SizedBox(
                      width: 172,
                      child: HomeFeedItemCard(
                        item: section.items[i],
                        onTap: () => openHomeFeedItem(
                          context,
                          section.items[i],
                          controller.repository,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }, childCount: controller.sections.length + 1),
    ),
  );
}

class HomeFeedResultsScreen extends StatefulWidget {
  final String title;
  final String? sectionId;
  final HomeFeedItem? vendor;
  final HomeFeedRepository repository;
  final double? lat, lng;
  const HomeFeedResultsScreen({
    super.key,
    required this.title,
    this.sectionId,
    this.vendor,
    required this.repository,
    this.lat,
    this.lng,
  });
  @override
  State<HomeFeedResultsScreen> createState() => _HomeFeedResultsScreenState();
}

class _HomeFeedResultsScreenState extends State<HomeFeedResultsScreen> {
  final items = <HomeFeedItem>[];
  bool loading = false, more = true;
  int offset = 0;
  Object? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (loading || !more) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = widget.vendor != null
          ? await widget.repository.vendorServices(widget.vendor!.id, offset)
          : await widget.repository.items(
              widget.sectionId!,
              offset,
              lat: widget.lat,
              lng: widget.lng,
            );
      if (!mounted) return;
      final rows = (data['items'] as List)
          .map((e) => HomeFeedItem(Map<String, dynamic>.from(e as Map)))
          .toList();
      setState(() {
        items.addAll(rows);
        offset += rows.length;
        more = data['has_more'] == true && rows.isNotEmpty;
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.axis == Axis.vertical &&
            n.metrics.extentAfter < 400 &&
            error == null) {
          load();
        }
        return false;
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.vendor?.description.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(widget.vendor!.description),
            ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final item in items)
                SizedBox(
                  width: (MediaQuery.sizeOf(context).width - 44) / 2,
                  child: HomeFeedItemCard(
                    item: item,
                    onTap: () =>
                        openHomeFeedItem(context, item, widget.repository),
                  ),
                ),
            ],
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (error != null)
            TextButton(
              onPressed: load,
              child: const Text('Unable to load. Retry'),
            ),
          if (!loading && items.isEmpty && error == null)
            const Center(child: Text('No services available right now.')),
          if (!loading && more && error == null)
            TextButton(onPressed: load, child: const Text('Load more')),
        ],
      ),
    ),
  );
}
