import 'package:eventor_customer/services/app_settings_controller.dart';

import '../../models/service_model.dart';
import 'search_screen.dart';
import '../../widgets/search/filter_sort_sheet.dart';
import '../../widgets/search/search_filter_button.dart';
import '../../widgets/search/result_cards.dart';

import 'package:flutter/material.dart';

import '../../models/customer_search_model.dart';
import '../../repositories/customer_search_repository.dart';
import '../../repositories/home_feed_repository.dart';
import '../../services/app_live_data.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/home_feed_widgets.dart';
import '../../widgets/common/global_search_bar.dart';

/// Owns submitted search cards, pagination and result navigation.
class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.query,
    this.categoryId,
    this.repository,
    this.onOpen,
    this.onServiceOpen,
  });
  final String query;
  final String? categoryId;
  final CustomerSearchRepository? repository;
  final ValueChanged<CustomerSearchResult>? onOpen;
  final ValueChanged<ServiceModel>? onServiceOpen;
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with LiveDataState<ResultScreen> {
  @override
  Set<String> get liveDatasets => {
    'public:services',
    'public:businesses',
    'public:vendors',
    'public:category_nodes',
    'public:event_types',
  };
  @override
  Future<void> onLiveData(Set<String> changed) => load(quiet: true);
  late final repo = widget.repository ?? CustomerSearchRepository();
  late final query = normalizeSearch(widget.query);
  final scroll = ScrollController();
  List<CustomerSearchResult> results = [];
  String kind = 'all', sort = 'relevance';
  static const types = {
    'all': 'All',
    'services': 'Services',
    'vendors': 'Vendors',
  };
  late final searchInput = TextEditingController(text: query);
  bool loading = false, failed = false, more = false;
  int generation = 0, offset = 0;
  @override
  void initState() {
    super.initState();
    load();
    scroll.addListener(() => _more());
  }

  void _more() {
    if (scroll.hasClients &&
        scroll.position.extentAfter < 250 &&
        more &&
        !loading &&
        !failed) {
      load(append: true);
    }
  }

  @override
  void dispose() {
    searchInput.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> load({bool append = false, bool quiet = false}) async {
    if (append && loading) return;
    final request = append ? generation : ++generation;
    final pageOffset = append ? offset : 0;
    if (widget.categoryId == null && query.length < 2) {
      setState(() => loading = false);
      return;
    }
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final page = widget.categoryId != null
          ? await repo.categoryResults(
              widget.categoryId!,
              kind: kind,
              sort: sort,
              offset: pageOffset,
            )
          : sort == 'relevance'
          ? await repo.search(query, kind: kind, offset: pageOffset)
          : await repo.searchFiltered(
              query,
              kind: kind,
              sort: sort,
              offset: pageOffset,
            );
      if (!mounted || request != generation) return;
      setState(() {
        results = append
            ? {
                for (final item in [...results, ...page.items]) item.id: item,
              }.values.toList()
            : page.items;
        offset = pageOffset + page.items.length;
        more = page.hasMore;
        loading = false;
      });
    } catch (_) {
      if (mounted && request == generation) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  void select({String? type, String? order}) {
    setState(() {
      kind = type ?? kind;
      sort = order ?? sort;
      results = [];
      more = false;
      offset = 0;
    });
    if (scroll.hasClients) scroll.jumpTo(0);
    load();
  }

  Future<void> filters() async {
    final choice = await showSearchFilterSortSheet(
      context,
      selection: SearchFilterSelection(type: kind, sort: sort),
      typeOptions: types,
      categoryOptions: const {'all': 'All categories'},
    );
    if (choice != null && mounted) {
      select(type: choice.type, order: choice.sort);
    }
  }

  Widget filterChips() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
    child: Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final option in types.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(option.value),
                      selected: kind == option.key,
                      showCheckmark: false,
                      selectedColor: const Color(0xFFF5E8EC),
                      labelStyle: TextStyle(
                        color: kind == option.key
                            ? const Color(0xFF80152C)
                            : const Color(0xFF73737D),
                      ),
                      onSelected: (_) => select(type: option.key),
                    ),
                  ),
                for (final option in customerSearchSorts.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(option.value),
                      selected: sort == option.key,
                      showCheckmark: false,
                      selectedColor: const Color(0xFFF5E8EC),
                      labelStyle: TextStyle(
                        color: sort == option.key
                            ? const Color(0xFF80152C)
                            : const Color(0xFF73737D),
                      ),
                      onSelected: (_) => select(order: option.key),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 5),
        SearchFilterButton(
          onPressed: filters,
          tooltip: AppSettingsScope.translate(
            context,
            "customer.filter_sort.8d76c3b1",
          ),
          active: kind != 'all' || sort != 'relevance',
        ),
      ],
    ),
  );

  void open(CustomerSearchResult result) {
    if (widget.onOpen != null) {
      widget.onOpen!(result);
      return;
    }
    final service = result.data['service'];
    if (!result.isVendor && widget.onServiceOpen != null && service is Map) {
      widget.onServiceOpen!(
        ServiceModel.fromMap(Map<String, dynamic>.from(service)),
      );
      return;
    }
    openHomeFeedItem(
      context,
      result.feedItem,
      HomeFeedRepository(client: repo.db),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F8FA),
    appBar: AppBar(
      toolbarHeight: 65,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: GlobalSearchBar(
          controller: searchInput,
          onChanged: (_) {},
          hintText: AppSettingsScope.translate(
            context,
            "customer.search_services_and_vendors.596e4c2f",
          ),
          readOnly: true,
          onTap: () {
            if (widget.categoryId == null) {
              Navigator.of(context).maybePop();
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CustomerSearchScreen(
                    repository: repo,
                    onOpen: widget.onOpen,
                  ),
                ),
              );
            }
          },
        ),
      ),
    ),
    body: Column(
      children: [
        filterChips(),
        if (loading)
          const LinearProgressIndicator(minHeight: 2, color: Color(0xFF80152C)),
        Expanded(
          child: RefreshIndicator(
            onRefresh: load,
            child: CustomScrollView(
              controller: scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: ResultCards(results: results, onOpen: open),
                ),
                if (failed)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          Text(
                            AppSettingsScope.translate(
                              context,
                              "customer.unable_to_search_check_your_connection_and_re.ec154eca",
                            ),
                          ),
                          TextButton(
                            onPressed: () => load(append: results.isNotEmpty),
                            child: Text(
                              AppSettingsScope.translate(
                                context,
                                "customer.retry.942087cc",
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!loading && !failed && results.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: AppEmptyState(
                        icon: Icons.search_off_rounded,
                        title: AppSettingsScope.translate(
                          context,
                          "customer.no_results_found.7d7e3605",
                        ),
                        message: AppSettingsScope.translate(
                          context,
                          "customer.try_a_service_vendor_category_or_event_name.155c904d",
                        ),
                        buttonText: AppSettingsScope.translate(
                          context,
                          "customer.try_another_search.aadc1506",
                        ),
                        onButtonPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                if (more && !loading && !failed)
                  SliverToBoxAdapter(
                    child: TextButton(
                      onPressed: () => load(append: true),
                      child: Text(
                        AppSettingsScope.translate(
                          context,
                          "customer.load_more_results.e03f1e48",
                        ),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
