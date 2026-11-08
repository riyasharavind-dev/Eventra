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
  String t(String en, String ta) => listingText(context, en, ta);
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
      throw StateError(t('Please sign in again.', 'மீண்டும் உள்நுழையவும்.'));
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
    'all': t('All businesses', 'அனைத்து வணிகங்கள்'),
    ...businessNames,
    for (final s in services)
      if (s.businessId != null && !businessNames.containsKey(s.businessId))
        s.businessId!: t('Business', 'வணிகம்'),
    if (services.any((s) => s.businessId == null))
      'unassigned': t('Unassigned', 'ஒதுக்கப்படாதவை'),
  };
  Map<String, String> get categoryOptions => {
    'all': t('All categories', 'அனைத்து வகைகள்'),
    for (final s in services)
      s.categoryNodeId: s.categoryName ?? t('Category', 'வகை'),
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
    'active' => t('Active', 'செயலில்'),
    'inactive' => t('Inactive', 'செயலற்றவை'),
    _ => t('All', 'அனைத்தும்'),
  };

  Future<void> addBusiness() async {
    if (adding) return;
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
    if (busyIds.contains(s.id)) {
      return;
    }
    setState(() => busyIds.add(s.id));
    try {
      if (target == 'edit' || target == 'gallery') {
        final fresh = await repo.getServiceById(s.id);
        if (fresh == null) {
          throw StateError(
            t(
              'Service no longer exists. Refresh the list.',
              'சேவை இல்லை. பட்டியலைப் புதுப்பிக்கவும்.',
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
                  ? t('Service activated.', 'சேவை செயல்படுத்தப்பட்டது.')
                  : t('Service is inactive.', 'சேவை செயலற்ற நிலையில் உள்ளது.'),
            ),
          ),
        );
      } else if (target == 'delete') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(t('Delete Service?', 'சேவையை நீக்கவா?')),
            content: Text(
              '${s.name}\n\n${t('This permanently deletes the service. Existing database rules may also delete linked bookings. This cannot be undone.', 'இது சேவையை நிரந்தரமாக நீக்கும். தற்போதைய தரவுத்தள விதிகளின்படி இணைந்த முன்பதிவுகளும் நீக்கப்படலாம். இதை மீட்டெடுக்க முடியாது.')}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(t('Cancel', 'ரத்து செய்')),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(c, true),
                child: Text(t('Delete', 'நீக்கு')),
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
          SnackBar(content: Text(t('Service deleted.', 'சேவை நீக்கப்பட்டது.'))),
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
                child: Text(t('Retry', 'மீண்டும் முயற்சி')),
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
                tooltip: t('Add', 'சேர்'),
                actions: [
                  FloatingMenuAction(
                    label: t('Add a business', 'வணிகம் சேர்'),
                    icon: Icons.storefront_outlined,
                    onSelected: addBusiness,
                  ),
                  FloatingMenuAction(
                    label: t('Add a service', 'சேவை சேர்'),
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
                        t('Listings', 'சேவைகள்'),
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
                              hintText: t(
                                'Search services...',
                                'சேவைகளைத் தேடு...',
                              ),
                              clearLabel: t('Clear search', 'தேடலை அழி'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          VendorFilterButton(
                            onPressed: filters,
                            tooltip: t(
                              'Filter & Sort',
                              'வடிகட்டி வரிசைப்படுத்து',
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
                            for (final v in ['all', 'active', 'inactive'])
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
                                        '${_statusLabel(v)} (${v == 'all' ? base.length : base.where((s) => s.isActive == (v == 'active')).length})',
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
                            label: Text(t('Clear filters', 'வடிகட்டல்களை அழி')),
                          ),
                        ),
                      if (error != null && services.isNotEmpty)
                        TextButton.icon(
                          onPressed: load,
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            t(
                              'Unable to refresh. Showing saved listings. Retry',
                              'புதுப்பிக்க முடியவில்லை. முந்தைய சேவைகள் காட்டப்படுகின்றன. மீண்டும் முயற்சி',
                            ),
                          ),
                        ),
                      if (businessError != null)
                        TextButton(
                          onPressed: load,
                          child: Text(
                            t(
                              'Could not load business names. Retry',
                              'வணிகப் பெயர்களை ஏற்ற முடியவில்லை. மீண்டும் முயற்சி',
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
                    t('Could not load services', 'சேவைகளை ஏற்ற முடியவில்லை'),
                    t('Please try again.', 'மீண்டும் முயற்சிக்கவும்.'),
                    retry: true,
                  ),
                )
              else if (services.isEmpty && businessError != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: message(
                    t(
                      'Could not load businesses',
                      'வணிகங்களை ஏற்ற முடியவில்லை',
                    ),
                    t('Please try again.', 'மீண்டும் முயற்சிக்கவும்.'),
                    retry: true,
                  ),
                )
              else if (services.isEmpty && needsBusiness)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: message(
                    t(
                      'Add a business to get started',
                      'தொடங்க ஒரு வணிகத்தைச் சேர்க்கவும்',
                    ),
                    t(
                      'You need an active business before you can add services.',
                      'சேவைகளைச் சேர்க்க செயலில் உள்ள வணிகம் தேவை.',
                    ),
                    icon: Icons.storefront_outlined,
                    actionLabel: t('Add a business', 'வணிகத்தைச் சேர்'),
                    onAction: addBusiness,
                  ),
                )
              else if (rows.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: message(
                    services.isEmpty
                        ? t('No services yet', 'இன்னும் சேவைகள் இல்லை')
                        : t('No matching services', 'பொருத்தமான சேவைகள் இல்லை'),
                    services.isEmpty
                        ? ''
                        : t(
                            'Try a different search or clear your filters.',
                            'வேறு தேடலை முயற்சிக்கவும் அல்லது வடிகட்டல்களை அழிக்கவும்.',
                          ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
                  sliver: SliverList.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final s = rows[i],
                          metrics = listingMetrics[rows[i].id] as Map?;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ListingCard(
                          service: s,
                          businessName: businessNames[s.businessId],
                          bookingCount: (metrics?['bookings'] as num?)?.toInt(),
                          rating: (metrics?['rating'] as num?)?.toDouble(),
                          busy: busyIds.contains(s.id),
                          onOpen: () => open(s),
                          onAction: (value) => action(s, value),
                        ),
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
