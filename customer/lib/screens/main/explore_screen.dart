import 'package:eventor_customer/services/app_settings_controller.dart';

import '../../services/app_live_data.dart';

import 'package:flutter/material.dart';

import '../../models/explore_data.dart';
import '../../models/category_node_model.dart';
import '../../models/service_model.dart';
import '../../repositories/explore_repository.dart';
import '../../widgets/explore/explore_categories.dart';
import '../../widgets/explore/explore_cards.dart';
import '../extended/result_screen.dart';
import '../../repositories/customer_search_repository.dart';
import '../extended/search_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    this.repository,
    this.onOpen,
    this.resultRepository,
  });
  final ExploreRepository? repository;
  final CustomerSearchRepository? resultRepository;
  final ValueChanged<ServiceModel>? onOpen;
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with LiveDataState<ExploreScreen> {
  @override
  Set<String> get liveDatasets => {
    'public:category_nodes',
    'public:category_trends',
    'public:services',
    'public:businesses',
    'public:vendors',
    'public:event_types',
  };
  @override
  Future<void> onLiveData(Set<String> changed) async {
    await _load();
  }

  late final ExploreRepository _repository;
  final _scroll = ScrollController();
  ExploreData? _data;
  bool _loading = true, _failed = false;
  String? _selected;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? ExploreRepository();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      if (!liveRefreshing) _loading = _data == null;
      _failed = false;
    });
    try {
      final data = await _repository.load();
      if (!mounted || generation != _generation) return;
      setState(() {
        _data = data;
        _loading = false;
        if (!data.categories.any((category) => category.id == _selected)) {
          _selected = null;
        }
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  void _select(String? id) {
    setState(() => _selected = id);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _openCategory(CategoryNodeModel category) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(
          query: category.name,
          categoryId: category.id,
          repository: widget.resultRepository,
          onServiceOpen: widget.onOpen,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final parents = data?.parents ?? <CategoryNodeModel>[];
    final selected = parents.where((c) => c.id == _selected).firstOrNull;
    final categories = selected == null
        ? parents
        : data!.descendantsFor(selected.id);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppSettingsScope.translate(
                        context,
                        "customer.explore.3b73900b",
                      ),
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF171720),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: AppSettingsScope.translate(
                      context,
                      "customer.search.49c266ba",
                    ),
                    icon: const Icon(Icons.search, color: Color(0xFF73737D)),
                    onPressed: () async {
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const CustomerSearchScreen(),
                        ),
                      );
                      if (mounted) await _load();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFECECF1)),
            if (_loading)
              const LinearProgressIndicator(minHeight: 2, color: exploreWine),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ExploreCategoryRail(
                    categories: data?.parents ?? [],
                    selected: selected?.id,
                    onSelect: _select,
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      color: exploreWine,
                      child: CustomScrollView(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          if (_failed)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppSettingsScope.translate(
                                        context,
                                        "customer.unable_to_refresh_explore_please_retry.e7ce3416",
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _load,
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
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                16,
                                12,
                                128,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selected?.name ?? 'Browse categories',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  if (!_loading && categories.isEmpty)
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 20,
                                      ),
                                      child: Text(
                                        AppSettingsScope.translate(
                                          context,
                                          "customer.no_subcategories_yet.df3122d5",
                                        ),
                                      ),
                                    ),
                                  ExploreCards(
                                    categories: categories,
                                    onSelect: (category) {
                                      if (selected == null) {
                                        _select(category.id);
                                      } else {
                                        _openCategory(category);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
