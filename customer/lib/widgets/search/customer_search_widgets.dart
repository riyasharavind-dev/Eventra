import 'package:flutter/material.dart';

import '../../models/customer_search_model.dart';

const searchWine = Color(0xFF80152C);

class CustomerSearchInput extends StatelessWidget
    implements PreferredSizeWidget {
  const CustomerSearchInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmit,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged, onSubmit;
  @override
  Size get preferredSize => const Size.fromHeight(66);
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 12, 10),
      child: Row(
        children: [
          const BackButton(),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              maxLength: 80,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              onSubmitted: onSubmit,
              decoration: InputDecoration(
                hintText: 'Search services, vendors or events',
                hintStyle: const TextStyle(fontSize: 13),
                counterText: '',
                filled: true,
                fillColor: const Color(0xFFF7F5F7),
                prefixIcon: const Icon(Icons.search_rounded, color: searchWine),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, child) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            controller.clear();
                            onChanged('');
                            focusNode.requestFocus();
                          },
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE8E5EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE8E5EB)),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class RecentSearches extends StatelessWidget {
  const RecentSearches({
    super.key,
    required this.searches,
    required this.onSelect,
    required this.onRemove,
    required this.onClear,
  });
  final List<RecentCustomerSearch> searches;
  final ValueChanged<String> onSelect, onRemove;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Recent searches',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(onPressed: onClear, child: const Text('Clear all')),
        ],
      ),
      for (final search in searches)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.history_rounded, color: Color(0xFF73737D)),
          title: Text(
            search.query,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => onSelect(search.query),
          trailing: IconButton(
            tooltip: 'Remove ${search.query}',
            onPressed: () => onRemove(search.query),
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ),
    ],
  );
}

class CustomerSearchResultTile extends StatelessWidget {
  const CustomerSearchResultTile({
    super.key,
    required this.result,
    required this.onOpen,
    this.suggestion = false,
    this.onFill,
  });
  final CustomerSearchResult result;
  final VoidCallback onOpen;
  final bool suggestion;
  final VoidCallback? onFill;
  @override
  Widget build(BuildContext context) {
    final item = result.feedItem;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFECECF1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (suggestion)
                Icon(
                  result.isVendor
                      ? Icons.storefront_outlined
                      : Icons.search_rounded,
                  color: const Color(0xFF73737D),
                  size: 23,
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 76,
                    height: 84,
                    child: item.image?.isNotEmpty == true
                        ? Image.network(
                            item.image!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, error, stack) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF73737D),
                      ),
                    ),
                    if (!suggestion) ...[
                      const SizedBox(height: 7),
                      Text(
                        result.isVendor
                            ? '${item.data['completed_count'] ?? 0} completed events'
                            : result.priceLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          color: searchWine,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (item.rating != null)
                        Text(
                          '★ ${item.rating!.toStringAsFixed(1)} · ${item.data['review_count']} reviews',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF73737D),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              if (suggestion)
                IconButton(
                  tooltip: 'Search ${result.name}',
                  onPressed: onFill,
                  icon: const Icon(Icons.north_west_rounded, size: 19),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.black,
                    size: 22,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => ColoredBox(
    color: const Color(0xFFF8F0F3),
    child: Icon(
      result.isVendor ? Icons.storefront_outlined : Icons.event_outlined,
      color: searchWine,
      size: 30,
    ),
  );
}

class CustomerSearchFilters extends StatelessWidget {
  const CustomerSearchFilters({
    super.key,
    required this.selected,
    required this.onSelect,
  });
  final String selected;
  final ValueChanged<String> onSelect;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final entry in const {
          'all': 'All',
          'services': 'Services',
          'vendors': 'Vendors',
        }.entries)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(entry.value),
              selected: selected == entry.key,
              onSelected: (_) => onSelect(entry.key),
              selectedColor: const Color(0xFFF3E5EA),
              labelStyle: TextStyle(
                color: selected == entry.key
                    ? searchWine
                    : const Color(0xFF555561),
              ),
            ),
          ),
      ],
    ),
  );
}
