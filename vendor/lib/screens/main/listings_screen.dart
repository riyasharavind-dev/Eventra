import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:eventor_vendor/services/app_settings_controller.dart';

import '../../services/vendor_tour_controller.dart';

import 'package:eventor_vendor/core/theme/app_icon_colors.dart';

import '../../services/app_live_data.dart';
import '../../widgets/vendor_filter_button.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/expandable_action_button.dart';
import '../../models/business_model.dart';
import '../extended/business_details.dart';
import '../../widgets/common/global_search_bar.dart';
import '../../widgets/listings/listing_filter_sheet.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/service_model.dart';
import '../../models/listing_filter.dart';
import '../../repositories/service_repository.dart';
import '../../widgets/listings/listing_ui.dart';
import '../extended/listing_detail_screen.dart';
import '../extended/listing_editor_screen.dart';

class ListingsScreen extends StatefulWidget {
  final ServiceRepository? repository;
  final SupabaseClient? client;
  final Future<List<Map<String, dynamic>>> Function()? loadBusinesses;
  final Future<Map<String, dynamic>> Function()? loadMetrics;
  const ListingsScreen({
    super.key,
    this.repository,
    this.client,
    this.loadBusinesses,
    this.loadMetrics,
  });
  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen>
    with LiveDataState<ListingsScreen> {
  @override
  bool get liveCanRefresh => busyIds.isEmpty && !adding;
  @override
  Set<String> get liveDatasets => {
    'own:services',
    'own:businesses',
    'own:service_reviews',
    'own:service_metrics',
    'public:category_nodes',
  };
  @override
  Future<void> onLiveData(Set<String> changed) async {
    await load();
  }

  late final ServiceRepository repo;
  SupabaseClient get db => widget.client ?? Supabase.instance.client;
  final search = TextEditingController();
  List<ServiceModel> services = [];
  Map<String, String> businessNames = {};
  Map<String, dynamic> listingMetrics = {};
  final busyIds = <String>{};
  String status = 'all', business = 'all', category = 'all', sort = 'newest';
  bool loading = true, adding = false;
  Object? error, businessError;
  int generation = 0;
  bool hasActiveBusiness = false;
  bool get needsBusiness =>
      !loading && error == null && businessError == null && !hasActiveBusiness;
  String t(String en) => AppSettingsScope.source(context, en);
  @override
  void initState() {
    super.initState();
    repo = widget.repository ?? ServiceRepository(supabase: db);
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> loadBusinessNames() async {
    if (widget.loadBusinesses != null) {
      return widget.loadBusinesses!();
    }
    final uid = db.auth.currentUser?.id;
    if (uid == null) {
      throw StateError(
        AppSettingsScope.translate(
          context,
          "vendor.please_sign_in_again.2e1d1833",
        ),
      );
    }
    return List<Map<String, dynamic>>.from(
      await db
          .from('businesses')
          .select('id,name,is_active')
          .eq('vendor_id', uid)
          .order('name'),
    );
  }

  Future<void> load() async {
    if (!mounted) {
      return;
    }
    final request = ++generation;
    setState(() {
      if (!liveRefreshing) loading = true;
      error = null;
      businessError = null;
    });
    try {
      final rowsFuture = repo.getMyServices();
      final businessFuture = loadBusinessNames().then<Object>(
        (v) => v,
        onError: (Object e) => e,
      );
      final metricsFuture = (() async {
        try {
          return Map<String, dynamic>.from(
            (widget.loadMetrics != null
                    ? await widget.loadMetrics!()
                    : await db.rpc('get_vendor_listing_metrics'))
                as Map,
          );
        } catch (_) {
          return <String, dynamic>{};
        }
      })();
      final rows = await rowsFuture;
      Map<String, dynamic> metrics = {};
      try {
        metrics = await metricsFuture;
      } catch (_) {
        // Leave unknown metrics blank rather than showing invented zeroes.
      }
      Map<String, String> names = businessNames;
      Object? namesError;
      bool activeBusiness = hasActiveBusiness;
      try {
        final result = await businessFuture;
        if (result is! List<Map<String, dynamic>>) throw result;
        final businesses = result;
        activeBusiness = businesses.any((b) => b['is_active'] == true);
        names = {
          for (final b in businesses) b['id'] as String: b['name'].toString(),
        };
      } catch (e) {
        namesError = e;
      }
      if (!mounted || request != generation) {
        return;
      }
      setState(() {
        services = rows;
        listingMetrics = metrics;
        businessNames = names;
        if (business != 'all' &&
            business != 'unassigned' &&
            !names.containsKey(business)) {
          business = 'all';
        }
        if (category != 'all' &&
            !rows.any((s) => s.categoryNodeId == category)) {
          category = 'all';
        }
        hasActiveBusiness = activeBusiness;
        businessError = namesError;
        loading = false;
      });
    } catch (e) {
      if (mounted && request == generation) {
        setState(() {
          error = e;
          loading = false;
        });
      }
    }
  }

  List<ServiceModel> filtered({String? chosenStatus}) => filterListings(
    services,
    query: search.text,
    status: chosenStatus ?? status,
    business: business,
    category: category,
    sort: sort,
  );
  Map<String, String> get businessOptions => {
    'all': AppSettingsScope.translate(
      context,
      "vendor.all_businesses.13312b22",
    ),
    ...businessNames,
    for (final s in services)
      if (s.businessId != null && !businessNames.containsKey(s.businessId))
        s.businessId!: AppSettingsScope.translate(
          context,
          "vendor.business.76f68a75",
        ),
    if (services.any((s) => s.businessId == null))
      'unassigned': AppSettingsScope.translate(
        context,
        "vendor.unassigned.14d33bd0",
      ),
  };
  Map<String, String> get categoryOptions => {
    'all': AppSettingsScope.translate(
      context,
      "vendor.all_categories.9d5097a8",
    ),
    for (final s in services)
      s.categoryNodeId:
          s.categoryName ??
          AppSettingsScope.translate(context, "vendor.category.292c06f0"),
  };
  Future<void> filters() async {
    final selection = await showListingFilterSheet(
      context,
      selection: ListingFilterSelection(
        business: business,
        category: category,
        sort: sort,
        status: status,
      ),
      businessOptions: businessOptions,
      categoryOptions: categoryOptions,
    );
    if (!mounted || selection == null) return;
    setState(() {
      business = selection.business;
      category = selection.category;
      sort = selection.sort;
      status = selection.status;
    });
  }

  String _statusLabel(String value) => switch (value) {
    'archived' => AppSettingsScope.translate(context, 'listing.archived'),
    'active' => AppSettingsScope.translate(context, "vendor.active.92340695"),
    'inactive' => AppSettingsScope.translate(
      context,
      "vendor.inactive.ac7c949f",
    ),
    _ => AppSettingsScope.translate(context, "vendor.all.a52ace42"),
  };

  Future<void> addBusiness() async {
    if (adding) return;
    VendorTourController.instance.businessOpened();
    setState(() => adding = true);
    try {
      final result = await Navigator.push<BusinessModel>(
        context,
        MaterialPageRoute(builder: (_) => const AddBusinessScreen()),
      );
      if (result != null) await load();
    } finally {
      if (mounted) setState(() => adding = false);
    }
  }

  Future<void> add() async {
    if (adding) {
      return;
    }
    setState(() => adding = true);
    try {
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ListingEditorScreen(client: widget.client),
        ),
      );
      if (saved == true) {
        await load();
      }
    } finally {
      if (mounted) {
        setState(() => adding = false);
      }
    }
  }

  Future<void> open(ServiceModel s) async {
    if (busyIds.contains(s.id)) {
      return;
    }
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (detailContext) => ListingDetailScreen(
          service: s,
          onEdit: () => Navigator.pop(detailContext, 'edit'),
          onManageImages: () => Navigator.pop(detailContext, 'gallery'),
          onToggleStatus: () => Navigator.pop(detailContext, 'toggle'),
          onDelete: () => Navigator.pop(detailContext, 'delete'),
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    if (result != null) {
      await action(s, result);
    } else {
      await load();
    }
  }

  Future<void> action(ServiceModel s, String target) async {
    final l10n = AppSettingsScope.localizationOf(context);
    if (busyIds.contains(s.id)) {
      return;
    }
    setState(() => busyIds.add(s.id));
    try {
      if (target == 'edit' || target == 'gallery') {
        final fresh = await repo.getServiceById(s.id);
        if (fresh == null) {
          throw StateError(
            l10n.tr(
              "vendor.service_no_longer_exists_refresh_the_list.28f90eb5",
            ),
          );
        }
        if (!mounted) {
          return;
        }
        final saved = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => ListingEditorScreen(
              service: fresh,
              client: widget.client,
              focusGallery: target == 'gallery',
            ),
          ),
        );
        if (saved == true) {
          await load();
        }
      } else if (target == 'archive' || target == 'restore') {
        final fresh = await repo.getServiceById(s.id);
        if (fresh == null) throw StateError('Service no longer exists.');
        final updated = await repo.setArchived(fresh, target == 'archive');
        if (!mounted) return;
        setState(() {
          services = services
              .map((item) => item.id == updated.id ? updated : item)
              .toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.tr(
                updated.isArchived
                    ? 'listing.archived_message'
                    : 'listing.restored_message',
              ),
            ),
          ),
        );
      } else if (target == 'toggle') {
        final fresh = await repo.getServiceById(s.id);
        if (fresh == null) throw StateError('Service no longer exists.');
        final updated = await repo.toggleServiceStatus(fresh);
        if (!mounted) {
          return;
        }
        setState(() {
          services = services
              .map((item) => item.id == updated.id ? updated : item)
              .toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updated.isActive
                  ? l10n.tr("vendor.service_activated.2b110df1")
                  : l10n.tr("vendor.service_is_inactive.0f3ea731"),
            ),
          ),
        );
      } else if (target == 'delete') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l10n.tr("vendor.delete_service.ad8681fb")),
            content: Text(
              '${s.name}\n\n${l10n.tr("vendor.this_permanently_deletes_the_service_existing.cf128fba")}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(l10n.tr("vendor.cancel.19766ed6")),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(c, true),
                child: Text(l10n.tr("vendor.delete.e2d0a549")),
              ),
            ],
          ),
        );
        if (confirmed != true) {
          return;
        }
        await repo.deleteService(s);
        if (!mounted) {
          return;
        }
        setState(() => services.removeWhere((item) => item.id == s.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.tr("vendor.service_deleted.4329f8ee"))),
        );
      }
    } catch (e) {
      if (mounted) {
        listingError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => busyIds.remove(s.id));
      }
    }
  }

  Widget message(
    String title,
    String description, {
    bool retry = false,
    String? actionLabel,
    VoidCallback? onAction,
    IconData icon = Icons.inventory_2_outlined,
  }) {
    const wine = Color(0xFF80152C);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFF5E8EC),
                shape: BoxShape.circle,
              ),
              child: Icon(
                retry ? Icons.cloud_off_outlined : icon,
                size: 32,
                color: AppIconColors.standard,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF17171B),
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF73737D)),
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: adding ? null : onAction,
                icon: const Icon(Icons.add_rounded),
                label: Text(actionLabel),
                style: FilledButton.styleFrom(
                  backgroundColor: wine,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ],
            if (retry)
              TextButton(
                onPressed: load,
                style: TextButton.styleFrom(foregroundColor: wine),
                child: Text(
                  AppSettingsScope.translate(context, "vendor.retry.942087cc"),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const wine = Color(0xFF80152C);
    final rows = filtered(), base = filtered(chosenStatus: 'all');
    final activeFilters =
        business != 'all' ||
        category != 'all' ||
        sort != 'newest' ||
        status != 'all';
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 104),
              child: ExpandableActionButton(
                key: const ValueKey('add-service-fab'),
                color: wine,
                busy: adding,
                tooltip: AppSettingsScope.translate(
                  context,
                  "vendor.add.9fd728c6",
                ),
                actions: [
                  FloatingMenuAction(
                    label: AppSettingsScope.translate(
                      context,
                      "vendor.add_a_business.258ffae0",
                    ),
                    tourId: TourTargets.business,
                    icon: Icons.storefront_outlined,
                    onSelected: addBusiness,
                  ),
                  FloatingMenuAction(
                    label: AppSettingsScope.translate(
                      context,
                      "vendor.add_a_service.066ae41e",
                    ),
                    icon: Icons.add_business_outlined,
                    onSelected: add,
                  ),
                ],
              ),
            ),
      body: SafeArea(
        child: AppShimmerRefreshIndicator(
          onRefresh: load,
          color: wine,
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppSettingsScope.translate(
                          context,
                          "vendor.listings.5009238d",
                        ),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF17171B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: GlobalSearchBar(
                              controller: search,
                              onChanged: (_) => setState(() {}),
                              hintText: AppSettingsScope.translate(
                                context,
                                "vendor.search_services.d0c1184b",
                              ),
                              clearLabel: AppSettingsScope.translate(
                                context,
                                "vendor.clear_search.3b7ea517",
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          VendorFilterButton(
                            onPressed: filters,
                            tooltip: AppSettingsScope.translate(
                              context,
                              "vendor.filter_sort.8d76c3b1",
                            ),
                            active: activeFilters,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final v in [
                              'all',
                              'active',
                              'inactive',
                              'archived',
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  selected: status == v,
                                  onSelected: (_) => setState(() => status = v),
                                  showCheckmark: false,
                                  selectedColor: wine,
                                  backgroundColor: Colors.white,
                                  side: BorderSide(
                                    color: status == v
                                        ? wine
                                        : const Color(0xFFE8E5EB),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.circle,
                                        size: 8,
                                        color: status == v
                                            ? Colors.white
                                            : v == 'active'
                                            ? const Color(0xFF00BE83)
                                            : const Color(0xFF89909F),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${_statusLabel(v)} (${v == 'all' ? base.length : filtered(chosenStatus: v).length})',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: status == v
                                              ? Colors.white
                                              : const Color(0xFF252839),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (activeFilters)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => setState(() {
                              business = 'all';
                              category = 'all';
                              sort = 'newest';
                              status = 'all';
                            }),
                            icon: const Icon(Icons.close, size: 15),
                            label: Text(
                              AppSettingsScope.translate(
                                context,
                                "vendor.clear_filters.7179ea00",
                              ),
                            ),
                          ),
                        ),
                      if (error != null && services.isNotEmpty)
                        TextButton.icon(
                          onPressed: load,
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            AppSettingsScope.translate(
                              context,
                              "vendor.unable_to_refresh_showing_saved_listings_retr.da36c157",
                            ),
                          ),
                        ),
                      if (businessError != null)
                        TextButton(
                          onPressed: load,
                          child: Text(
                            AppSettingsScope.translate(
                              context,
                              "vendor.could_not_load_business_names_retry.3bc61c13",
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),

              if (loading && services.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: AppContentSkeleton(layout: SkeletonLayout.listings),
                  ),
                )
              else if (error != null && services.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: message(
                    AppSettingsScope.translate(
                      context,
                      "vendor.could_not_load_services.d4edaa10",
                    ),
                    AppSettingsScope.translate(
                      context,
                      "vendor.please_try_again.eea4fb33",
                    ),
                    retry: true,
                  ),
                )
              else if (services.isEmpty && businessError != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: message(
                    AppSettingsScope.translate(
                      context,
                      "vendor.could_not_load_businesses.0596cc0e",
                    ),
                    AppSettingsScope.translate(
                      context,
                      "vendor.please_try_again.eea4fb33",
                    ),
                    retry: true,
                  ),
                )
              else if (services.isEmpty && needsBusiness)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: message(
                    AppSettingsScope.translate(
                      context,
                      "vendor.add_a_business_to_get_started.b11971fb",
                    ),
                    AppSettingsScope.translate(
                      context,
                      "vendor.you_need_an_active_business_before_you_can_ad.fd481827",
                    ),
                    icon: Icons.storefront_outlined,
                    actionLabel: AppSettingsScope.translate(
                      context,
                      "vendor.add_a_business.258ffae0",
                    ),
                    onAction: addBusiness,
                  ),
                )
              else if (rows.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: message(
                    services.isEmpty
                        ? AppSettingsScope.translate(
                            context,
                            "vendor.no_services_yet.0e523254",
                          )
                        : AppSettingsScope.translate(
                            context,
                            "vendor.no_matching_services.4b5a3176",
                          ),
                    services.isEmpty
                        ? ''
                        : AppSettingsScope.translate(
                            context,
                            "vendor.try_a_different_search_or_clear_your_filters.88d56d0d",
                          ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final columns = (constraints.crossAxisExtent / 180)
                          .floor()
                          .clamp(2, 5);
                      return SliverMasonryGrid.count(
                        crossAxisCount: columns,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 12,
                        childCount: rows.length,
                        itemBuilder: (context, i) {
                          final service = rows[i];
                          final metrics = listingMetrics[service.id] as Map?;
                          return ListingCard(
                            key: ValueKey(service.id),
                            service: service,
                            photoAspectRatio: const [0.72, 1.12, 0.9][i % 3],
                            bookingCount: (metrics?['bookings'] as num?)
                                ?.toInt(),
                            rating: (metrics?['rating'] as num?)?.toDouble(),
                            busy: busyIds.contains(service.id),
                            onOpen: () => open(service),
                            onAction: (value) => action(service, value),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
