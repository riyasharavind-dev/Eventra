import '../../services/app_live_data.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/customer_search_model.dart';
import '../../repositories/customer_search_repository.dart';
import '../../repositories/home_feed_repository.dart';
import '../../widgets/home_feed_widgets.dart';
import '../../widgets/search/customer_search_widgets.dart';

class CustomerSearchScreen extends StatefulWidget {
  const CustomerSearchScreen({
    super.key,
    this.repository,
    this.historyRepository,
    this.onOpen,
  });
  final CustomerSearchRepository? repository;
  final CustomerSearchHistoryRepository? historyRepository;
  final ValueChanged<CustomerSearchResult>? onOpen;
  @override
  State<CustomerSearchScreen> createState() => _CustomerSearchScreenState();
}

class _CustomerSearchScreenState extends State<CustomerSearchScreen>
    with LiveDataState<CustomerSearchScreen> {
  @override
  Set<String> get liveDatasets => {
    'public:services',
    'public:businesses',
    'public:vendors',
    'public:category_nodes',
    'public:event_types',
  };
  @override
  Future<void> onLiveData(Set<String> changed) async {
    if (submitted && query.length >= 2) {
      await _fetch(++generation);
    } else {
      await _loadBrowse();
    }
  }

  late final CustomerSearchRepository repo;
  late final CustomerSearchHistoryRepository historyRepo;
  final input = TextEditingController();
  final focus = FocusNode();
  final scroll = ScrollController();
  Timer? debounce;
  List<RecentCustomerSearch> history = [];
  List<String> browse = [];
  List<CustomerSearchResult> results = [];
  String query = '', kind = 'all';
  bool submitted = false,
      loading = false,
      more = false,
      failed = false,
      historyFailed = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    repo = widget.repository ?? CustomerSearchRepository();
    historyRepo = widget.historyRepository ?? repo.history();
    _loadHistory();
    _loadBrowse();
    scroll.addListener(() {
      if (scroll.hasClients &&
          scroll.position.extentAfter < 250 &&
          submitted &&
          more &&
          !loading &&
          !failed) {
        _fetch(generation, append: true);
      }
    });
  }

  @override
  void dispose() {
    debounce?.cancel();
    input.dispose();
    focus.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final rows = await historyRepo.load();
      if (mounted) {
        setState(() {
          history = rows;
          historyFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => historyFailed = true);
    }
  }

  Future<void> _loadBrowse() async {
    try {
      final names = await repo.browseSuggestions();
      if (mounted) setState(() => browse = names);
    } catch (_) {
      /* Search still works if category suggestions are unavailable. */
    }
  }

  Future<void> _editHistory(
    Future<List<RecentCustomerSearch>> operation,
  ) async {
    try {
      final rows = await operation;
      if (mounted) setState(() => history = rows);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update search history. Please retry.'),
          ),
        );
      }
    }
  }

  void _changed(String text) {
    debounce?.cancel();
    final request = ++generation;
    setState(() {
      query = normalizeSearch(text);
      submitted = false;
      kind = 'all';
      results = [];
      more = false;
      failed = false;
      loading = query.length >= 2;
    });
    if (query.length >= 2) {
      debounce = Timer(
        const Duration(milliseconds: 350),
        () => _fetch(request),
      );
    }
  }

  void _submit(String text) {
    final value = normalizeSearch(text);
    if (value.length < 2) return;
    debounce?.cancel();
    final request = ++generation;
    input.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    focus.unfocus();
    setState(() {
      query = value;
      submitted = true;
      kind = 'all';
      results = [];
      more = false;
      failed = false;
      if (!liveRefreshing) loading = true;
    });
    if (scroll.hasClients) scroll.jumpTo(0);
    _editHistory(historyRepo.remember(value));
    _fetch(request);
  }

  void _filter(String value) {
    if (kind == value) return;
    final request = ++generation;
    setState(() {
      kind = value;
      results = [];
      failed = false;
      more = false;
      if (!liveRefreshing) loading = true;
    });
    if (scroll.hasClients) scroll.jumpTo(0);
    _fetch(request);
  }

  Future<void> _fetch(int request, {bool append = false}) async {
    if (!mounted || request != generation) return;
    setState(() {
      if (!liveRefreshing) loading = true;
      failed = false;
    });
    final activeQuery = query, activeKind = kind;
    try {
      final page = await repo.search(
        activeQuery,
        kind: activeKind,
        offset: append ? results.length : 0,
      );
      if (!mounted || request != generation) return;
      setState(() {
        results = append ? [...results, ...page.items] : page.items;
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

  void _open(CustomerSearchResult result) {
    focus.unfocus();
    _editHistory(historyRepo.remember(query));
    if (widget.onOpen != null) {
      widget.onOpen!(result);
      return;
    }
    openHomeFeedItem(
      context,
      result.feedItem,
      HomeFeedRepository(client: repo.db),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recent = history
        .where(
          (row) =>
              query.isEmpty ||
              row.query.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomerSearchInput(
        controller: input,
        focusNode: focus,
        onChanged: _changed,
        onSubmit: _submit,
      ),
      body: Column(
        children: [
          if (loading)
            const LinearProgressIndicator(minHeight: 2, color: searchWine),
          if (submitted)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: CustomerSearchFilters(selected: kind, onSelect: _filter),
            ),
          Expanded(
            child: CustomScrollView(
              controller: scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                if (!submitted && recent.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: RecentSearches(
                        searches: recent,
                        onSelect: _submit,
                        onRemove: (text) =>
                            _editHistory(historyRepo.remove(text)),
                        onClear: () => _editHistory(historyRepo.clear()),
                      ),
                    ),
                  ),
                if (!submitted && historyFailed)
                  SliverToBoxAdapter(
                    child: TextButton(
                      onPressed: _loadHistory,
                      child: const Text('Could not load history. Retry'),
                    ),
                  ),
                if (query.isEmpty && browse.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Browse categories',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: browse
                                .map(
                                  (name) => ActionChip(
                                    label: Text(name),
                                    onPressed: () => _submit(name),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (query.isEmpty && recent.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Find services and vendors for your next event.',
                        style: TextStyle(color: Color(0xFF73737D)),
                      ),
                    ),
                  ),
                if (query.length == 1)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('Type at least 2 characters to search.'),
                    ),
                  ),
                if (query.length >= 2) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                      child: Text(
                        submitted ? 'Results for “$query”' : 'Suggestions',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: submitted
                          ? results.length
                          : results.length.clamp(0, 6),
                      itemBuilder: (context, index) => CustomerSearchResultTile(
                        key: ValueKey(results[index].id),
                        result: results[index],
                        suggestion: !submitted,
                        onOpen: () => _open(results[index]),
                        onFill: () => _submit(
                          results[index].name.length > 80
                              ? results[index].name.substring(0, 80)
                              : results[index].name,
                        ),
                      ),
                    ),
                  ),
                  if (failed)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            const Text(
                              'Unable to search. Check your connection and retry.',
                            ),
                            TextButton(
                              onPressed: () => _fetch(
                                generation,
                                append: results.isNotEmpty,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!loading && !failed && results.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.search_off_rounded,
                              size: 46,
                              color: Color(0xFF73737D),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No results found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Try a service, vendor, category or event name.',
                              textAlign: TextAlign.center,
                            ),
                            TextButton(
                              onPressed: () {
                                input.clear();
                                _changed('');
                                focus.requestFocus();
                              },
                              child: const Text('Try another search'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (submitted && more && !loading && !failed)
                    SliverToBoxAdapter(
                      child: TextButton(
                        onPressed: () => _fetch(generation, append: true),
                        child: const Text('Load more results'),
                      ),
                    ),
                  if (!submitted && results.isNotEmpty)
                    SliverToBoxAdapter(
                      child: TextButton(
                        onPressed: () => _submit(query),
                        child: Text('See all results for “$query”'),
                      ),
                    ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
