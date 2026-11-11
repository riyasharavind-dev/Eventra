import 'package:eventor_customer/services/app_settings_controller.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/customer_search_model.dart';
import '../../repositories/customer_search_repository.dart';
import '../../services/app_live_data.dart';
import '../../widgets/search/customer_search_widgets.dart';
import 'result_screen.dart';

/// Search entry, recent history and suggestions. Full results live in ResultScreen.
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
    if (query.length >= 2) {
      await fetch(++generation);
    }
  }

  late final repo = widget.repository ?? CustomerSearchRepository();
  late final historyRepo = widget.historyRepository ?? repo.history();
  final input = TextEditingController();
  final focus = FocusNode();
  Timer? debounce;
  List<RecentCustomerSearch> history = [];
  List<CustomerSearchResult> suggestions = [];
  String query = '';
  bool loading = false, failed = false, historyFailed = false, opening = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  @override
  void dispose() {
    debounce?.cancel();
    input.dispose();
    focus.dispose();
    super.dispose();
  }

  Future<void> loadHistory() async {
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

  Future<void> editHistory(Future<List<RecentCustomerSearch>> operation) async {
    try {
      final rows = await operation;
      if (mounted) setState(() => history = rows);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppSettingsScope.translate(
                context,
                "customer.could_not_update_search_history_please_retry.249ca0be",
              ),
            ),
          ),
        );
      }
    }
  }

  void changed(String value) {
    debounce?.cancel();
    final request = ++generation;
    setState(() {
      query = normalizeSearch(value);
      suggestions = [];
      failed = false;
      loading = query.length >= 2;
    });
    if (query.length >= 2) {
      debounce = Timer(const Duration(milliseconds: 350), () => fetch(request));
    }
  }

  Future<void> fetch(int request) async {
    if (!mounted || request != generation) return;
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final page = await repo.search(query);
      if (mounted && request == generation) {
        setState(() {
          suggestions = page.items.take(6).toList();
          loading = false;
        });
      }
    } catch (_) {
      if (mounted && request == generation) {
        setState(() {
          failed = true;
          loading = false;
        });
      }
    }
  }

  Future<void> record(String value) async {
    try {
      await repo.recordSearch(value);
    } catch (_) {}
  }

  Future<void> submit(String value) async {
    value = normalizeSearch(value);
    if (value.length < 2 || opening) return;
    if (value.length > 80) value = value.substring(0, 80);
    opening = true;
    debounce?.cancel();
    ++generation;
    input.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    focus.unfocus();
    setState(() {
      query = value;
      loading = false;
    });
    unawaited(editHistory(historyRepo.remember(value)));
    unawaited(record(value));
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            query: value,
            repository: repo,
            onOpen: widget.onOpen,
          ),
        ),
      );
    } finally {
      opening = false;
      if (mounted) {
        await loadHistory();
        if (mounted && query.length >= 2) unawaited(fetch(++generation));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recent = history
        .where(
          (r) =>
              query.isEmpty ||
              r.query.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: CustomerSearchInput(
        controller: input,
        focusNode: focus,
        onChanged: changed,
        onSubmit: submit,
      ),
      body: Column(
        children: [
          if (loading)
            const LinearProgressIndicator(minHeight: 2, color: searchWine),
          Expanded(
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                if (recent.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: RecentSearches(
                        searches: recent,
                        onSelect: submit,
                        onRemove: (text) =>
                            editHistory(historyRepo.remove(text)),
                        onClear: () => editHistory(historyRepo.clear()),
                      ),
                    ),
                  ),
                if (historyFailed)
                  SliverToBoxAdapter(
                    child: TextButton(
                      onPressed: loadHistory,
                      child: Text(
                        AppSettingsScope.translate(
                          context,
                          "customer.could_not_load_history_retry.5a649081",
                        ),
                      ),
                    ),
                  ),
                if (query.isEmpty && recent.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        AppSettingsScope.translate(
                          context,
                          "customer.find_services_and_vendors_for_your_next_event.f8990023",
                        ),
                        style: TextStyle(color: Color(0xFF73737D)),
                      ),
                    ),
                  ),
                if (query.length == 1)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        AppSettingsScope.translate(
                          context,
                          "customer.type_at_least_2_characters_to_search.96e38e17",
                        ),
                      ),
                    ),
                  ),
                if (query.length >= 2) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(18, 18, 18, 12),
                      child: Text(
                        AppSettingsScope.translate(
                          context,
                          "customer.suggestions.16c1d601",
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: suggestions.length,
                      itemBuilder: (_, index) {
                        final item = suggestions[index];
                        return ListTile(
                          key: ValueKey(item.id),
                          leading: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF73737D),
                          ),
                          title: Text(
                            item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => submit(item.name),
                        );
                      },
                    ),
                  ),
                  if (failed)
                    SliverToBoxAdapter(
                      child: TextButton(
                        onPressed: () => fetch(generation),
                        child: Text(
                          AppSettingsScope.translate(
                            context,
                            "customer.unable_to_load_suggestions_retry.44ed792e",
                          ),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: searchWine,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        onPressed: () => submit(query),
                        icon: const Icon(Icons.search_rounded, size: 18),
                        label: Text(
                          AppSettingsScope.translate(
                            context,
                            "customer.see_all_results_for_value0.97c42fef",
                            args: {"value0": query},
                          ),
                        ),
                      ),
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
