import 'package:flutter/material.dart';

import '../../models/explore_data.dart';
import '../../models/service_model.dart';
import '../../repositories/explore_repository.dart';
import '../../widgets/explore/explore_categories.dart';
import '../../widgets/explore/explore_service_card.dart';
import '../extended/service_details_screen.dart';
import '../extended/search_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, this.repository, this.onOpen});
  final ExploreRepository? repository;
  final ValueChanged<ServiceModel>? onOpen;
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
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
      _loading = true;
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

  void _open(ServiceModel service) {
    if (widget.onOpen != null) {
      widget.onOpen!(service);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ServiceDetailsScreen(service: service),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final services = data?.servicesFor(_selected) ?? <ServiceModel>[];
    final path = data?.pathFor(_selected) ?? [];
    final children = data?.childrenFor(_selected) ?? [];
    final root = path.isEmpty ? null : path.first.id;
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
                  const Expanded(
                    child: Text(
                      'Explore',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF171720),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Search',
                    icon: const Icon(Icons.search, color: Color(0xFF73737D)),
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const CustomerSearchScreen(),
                      ),
                    ),
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
                    selected: root,
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
                                    const Text(
                                      'Unable to refresh Explore. Please retry.',
                                    ),
                                    TextButton(
                                      onPressed: _load,
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (path.isNotEmpty)
                            SliverToBoxAdapter(
                              child: ExploreCategoryTrail(
                                path: path,
                                onSelect: _select,
                              ),
                            ),
                          if (children.isNotEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  16,
                                  12,
                                  20,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selected == null
                                          ? 'Browse categories'
                                          : 'Subcategories',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    ExploreChildCategories(
                                      categories: children,
                                      onSelect: (category) =>
                                          _select(category.id),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                              child: Text(
                                path.isEmpty
                                    ? 'All services'
                                    : '${path.last.name} services',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          if (!_loading && !_failed && services.isEmpty)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.all(18),
                                child: Text(
                                  'No services in this category yet.',
                                ),
                              ),
                            ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 128),
                            sliver: ExploreServiceGrid(
                              services: services,
                              onOpen: _open,
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
