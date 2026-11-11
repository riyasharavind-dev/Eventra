import 'package:eventor_customer/services/app_settings_controller.dart';

import 'vendor_profile_card.dart';
import 'common/global_search_bar.dart';
import '../screens/extended/search_screen.dart';

import 'dart:math' as math;

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

/// Shared sizing for Home feeds and search/category result cards.
int feedCardColumns(double availableWidth) =>
    (availableWidth / 180).floor().clamp(2, 4);
double feedCardWidth(double availableWidth) {
  final columns = feedCardColumns(availableWidth);
  return (availableWidth - (columns - 1) * 12) / columns;
}

double feedCardHeight(double width, TextScaler scaler) {
  final extraTextHeight = math.max(0.0, scaler.scale(13) / 13 - 1) * 64;
  // Reserve the complete three-line details area even on narrow phones.
  return width * .57 + math.max(width * .36, 68.0 + extraTextHeight);
}

double feedShelfHeight(BuildContext context) =>
    feedCardHeight(
      feedCardWidth(MediaQuery.sizeOf(context).width - 32),
      MediaQuery.textScalerOf(context),
    ) +
    12;

class HomeFeedItemCard extends StatelessWidget {
  final HomeFeedItem item;
  final VoidCallback onTap;
  const HomeFeedItemCard({super.key, required this.item, required this.onTap});
  @override
  Widget build(BuildContext context) {
    if (item.isVendor) return VendorProfileCard(item: item, onTap: onTap);
    final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
    final joined = DateTime.tryParse(
      item.data['vendor_joined_at']?.toString() ?? '',
    );
    final age = joined == null ? null : DateTime.now().difference(joined);
    final isNew =
        item.data['is_new_vendor'] == true ||
        (age != null && !age.isNegative && age.inDays < 30);
    final location = item.data['location']?.toString().trim();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: feedCardHeight(width, MediaQuery.textScalerOf(context)),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF0EDF0)),
              boxShadow: [
                BoxShadow(
                  color: _primaryWine.withValues(alpha: .05),
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
                    SizedBox(
                      height: width * .57,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: _softRose,
                            child: item.image?.isNotEmpty == true
                                ? Image.network(
                                    item.image!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.image_outlined,
                                      color: _primaryWine,
                                      size: 32,
                                    ),
                                  )
                                : const Icon(
                                    Icons.image_outlined,
                                    color: _primaryWine,
                                    size: 32,
                                  ),
                          ),
                          if (isNew)
                            Positioned(
                              top: 9,
                              right: 9,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  AppSettingsScope.translate(
                                    context,
                                    "customer.new.18fdd549",
                                  ),
                                  style: TextStyle(
                                    color: _primaryWine,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x99000000),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 14,
                                    color: _gold,
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
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 16 * scale,
                              child: Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.25,
                                  fontWeight: FontWeight.w800,
                                  color: _textDark,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
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
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: _textGrey,
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    location?.isNotEmpty == true
                                        ? location!
                                        : 'Location not added',
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
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class FeedSeeAllCard extends StatelessWidget {
  const FeedSeeAllCard({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 100,
    child: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: 180,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_forward_rounded, color: _primaryWine),
                SizedBox(height: 10),
                Text(
                  AppSettingsScope.translate(
                    context,
                    "customer.see_all.d7a8c446",
                  ),
                  style: TextStyle(
                    color: _primaryWine,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
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
            padding: const EdgeInsets.all(20),
            child: controller.loading
                ? const Center(child: CircularProgressIndicator())
                : controller.error != null
                ? Center(
                    child: TextButton(
                      onPressed: controller.loadMore,
                      child: Text(
                        AppSettingsScope.translate(
                          context,
                          "customer.unable_to_load_feed_retry.a0a2bb4f",
                        ),
                      ),
                    ),
                  )
                : controller.hasMore
                ? Center(
                    child: TextButton(
                      onPressed: controller.loadMore,
                      child: Text(
                        AppSettingsScope.translate(
                          context,
                          "customer.load_more_services.3a0db408",
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          );
        }
        final section = controller.sections[index];
        void seeAll() => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => HomeFeedResultsScreen(
              title: section.title,
              sectionId: section.id,
              repository: controller.repository,
              lat: controller.lat,
              lng: controller.lng,
            ),
          ),
        );
        return Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  section.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _textDark,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height:
                    section.items.isNotEmpty &&
                        section.items.every((item) => item.isVendor)
                    ? vendorProfileCardHeight(context) + 8
                    : feedShelfHeight(context),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: section.items.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => i == section.items.length
                      ? FeedSeeAllCard(onTap: seeAll)
                      : SizedBox(
                          width: section.items[i].isVendor
                              ? vendorProfileCardWidth(context)
                              : feedCardWidth(
                                  MediaQuery.sizeOf(context).width - 32,
                                ),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: HomeFeedItemCard(
                              item: section.items[i],
                              onTap: () => section.items[i].isVendor
                                  ? openVendorProfileCard(
                                      context,
                                      section.items[i],
                                    )
                                  : openHomeFeedItem(
                                      context,
                                      section.items[i],
                                      controller.repository,
                                    ),
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
  final String? businessId;
  final HomeFeedItem? vendor;
  final HomeFeedRepository repository;
  final double? lat, lng;
  const HomeFeedResultsScreen({
    super.key,
    required this.title,
    this.sectionId,
    this.businessId,
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
  final _searchInput = TextEditingController();
  @override
  void dispose() {
    _searchInput.dispose();
    super.dispose();
  }

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
      final data = widget.businessId != null
          ? await widget.repository.businessServices(widget.businessId!, 0)
          : widget.vendor != null
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
      final data = widget.businessId != null
          ? await widget.repository.businessServices(widget.businessId!, offset)
          : widget.vendor != null
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
      bottom: widget.businessId != null
          ? PreferredSize(
              preferredSize: const Size.fromHeight(65),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: GlobalSearchBar(
                  controller: _searchInput,
                  onChanged: (_) {},
                  hintText: AppSettingsScope.translate(
                    context,
                    "customer.search_services_vendors_or_events.c4e70feb",
                  ),
                  readOnly: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CustomerSearchScreen(),
                    ),
                  ),
                ),
              ),
            )
          : PreferredSize(
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
                  width: item.isVendor
                      ? vendorProfileCardWidth(context)
                      : feedCardWidth(MediaQuery.sizeOf(context).width - 32),
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
                  label: Text(
                    AppSettingsScope.translate(
                      context,
                      "customer.unable_to_load_tap_to_retry.773260ce",
                    ),
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          if (!loading && items.isEmpty && error == null)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  AppSettingsScope.translate(
                    context,
                    "customer.no_services_available_right_now.edc30ff4",
                  ),
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
                  child: Text(
                    AppSettingsScope.translate(
                      context,
                      "customer.load_more.ac8991ef",
                    ),
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
