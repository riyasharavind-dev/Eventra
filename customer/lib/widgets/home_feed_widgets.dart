import '../services/app_live_data.dart';
import '../models/service_pricing.dart';

import 'package:flutter/material.dart';

import '../models/home_feed.dart';
import '../models/service_model.dart';
import '../repositories/home_feed_repository.dart';
import '../screens/extended/service_details_screen.dart';

// =============================================================================
// COLOR PALETTE (MATCHING VENDOR APP / ME SCREEN)
// =============================================================================

const Color _primaryWine = Color(0xFF80152C);
const Color _gold = Color(0xFFFFCB48);
const Color _softRose = Color(0xFFF5E8EC);
const Color _background = Color(0xFFF8F8FA);
const Color _textDark = Color(0xFF17171B);
const Color _textGrey = Color(0xFF73737D);

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
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0EDF0), width: 1),
        boxShadow: [
          BoxShadow(
            color: _primaryWine.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 118,
                    width: double.infinity,
                    child: item.image?.isNotEmpty == true
                        ? Image.network(
                            item.image!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, error, stack) => Container(
                              color: _softRose,
                              child: const Center(
                                child: Icon(
                                  Icons.image_outlined,
                                  color: _primaryWine,
                                  size: 32,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: _softRose,
                            child: Center(
                              child: Icon(
                                item.isVendor
                                    ? Icons.storefront_outlined
                                    : Icons.event_outlined,
                                color: _primaryWine,
                                size: 38,
                              ),
                            ),
                          ),
                  ),
                  if (item.rating != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCC170208),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: _gold,
                              size: 13,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              item.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.isVendor
                          ? '${item.data['completed_count'] ?? 0} events completed'
                          : ServicePricing.fromMap(item.data)
                                .format(item.price.toDouble()),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _primaryWine,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.rating == null
                          ? 'New on Eventor'
                          : '${item.data['review_count'] ?? 0} reviews',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _textGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (item.data['distance_km'] != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 11,
                            color: _textGrey,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              '${item.data['distance_km']} km away',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _textGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: controller.loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: _primaryWine,
                      strokeWidth: 2.5,
                    ),
                  )
                : controller.error != null
                ? Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: _primaryWine,
                      ),
                      onPressed: controller.loadMore,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text(
                        'Unable to load feed. Tap to retry',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  )
                : controller.hasMore
                ? Center(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: _primaryWine,
                        backgroundColor: _softRose,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: controller.loadMore,
                      child: const Text(
                        'Load more services',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          );
        }
        final section = controller.sections[index];
        return Padding(
          padding: const EdgeInsets.only(top: 24),
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
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _textDark,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.push(
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'See All',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _primaryWine,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 11,
                              color: _primaryWine,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
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
                      256 +
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
                      width: 176,
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

class _HomeFeedResultsScreenState extends State<HomeFeedResultsScreen>
    with LiveDataState<HomeFeedResultsScreen> {
  int generation = 0;
  @override
  Set<String> get liveDatasets => {
    'public:services',
    'public:businesses',
    'public:vendors',
    'public:service_reviews',
    'public:service_metrics',
    'public:home_feed_sections',
    'public:home_feed_pinned_items',
  };
  @override
  Future<void> onLiveData(Set<String> changed) async {
    final request = ++generation;
    setState(() => loading = true);
    try {
      final data = widget.vendor != null
          ? await widget.repository.vendorServices(widget.vendor!.id, 0)
          : await widget.repository.items(
              widget.sectionId!,
              0,
              lat: widget.lat,
              lng: widget.lng,
            );
      if (!mounted || request != generation) return;
      final fresh = (data['items'] as List)
          .map((e) => HomeFeedItem(Map<String, dynamic>.from(e as Map)))
          .toList();
      setState(() {
        items
          ..clear()
          ..addAll(fresh);
        offset = fresh.length;
        more = data['has_more'] == true && fresh.isNotEmpty;
        error = null;
      });
    } catch (e) {
      if (mounted && request == generation) setState(() => error = e);
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

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
    final request = generation;
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
      if (!mounted || request != generation) return;
      final rows = (data['items'] as List)
          .map((e) => HomeFeedItem(Map<String, dynamic>.from(e as Map)))
          .toList();
      setState(() {
        final ids = items.map((e) => e.id).toSet();
        items.addAll(rows.where((e) => ids.add(e.id)));
        offset += rows.length;
        more = data['has_more'] == true && rows.isNotEmpty;
      });
    } catch (e) {
      if (mounted && request == generation) setState(() => error = e);
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      title: Text(
        widget.title,
        style: const TextStyle(
          color: _textDark,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      backgroundColor: Colors.white,
      foregroundColor: _textDark,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFF0EDF0), height: 1),
      ),
    ),
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
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF0EDF0)),
              ),
              child: Text(
                widget.vendor!.description,
                style: const TextStyle(
                  color: _textDark,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
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
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(
                  color: _primaryWine,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: _primaryWine),
                  onPressed: load,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Unable to load. Tap to retry',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          if (!loading && items.isEmpty && error == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No services available right now.',
                  style: TextStyle(color: _textGrey, fontSize: 14),
                ),
              ),
            ),
          if (!loading && more && error == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: _primaryWine,
                    backgroundColor: _softRose,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: load,
                  child: const Text(
                    'Load more',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
