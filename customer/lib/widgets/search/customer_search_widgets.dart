import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_icon_colors.dart';
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
      padding: const EdgeInsets.fromLTRB(4, 6, 16, 10),
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
                hintText: AppSettingsScope.translate(
                  context,
                  "customer.search_services_vendors_or_events.c4e70feb",
                ),
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF73737D),
                ),
                counterText: '',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppIconColors.standard,
                ),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, child) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: AppSettingsScope.translate(
                            context,
                            "customer.clear_search.3b7ea517",
                          ),
                          onPressed: () {
                            controller.clear();
                            onChanged('');
                            focusNode.requestFocus();
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: AppIconColors.standard,
                          ),
                        ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFF0EDF0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFF0EDF0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: searchWine, width: 1.5),
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
          Expanded(
            child: Text(
              AppSettingsScope.translate(
                context,
                "customer.recent_searches.228c84b5",
              ),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF17171B),
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: searchWine,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: onClear,
            child: Text(
              AppSettingsScope.translate(
                context,
                "customer.clear_all.29a390f9",
              ),
            ),
          ),
        ],
      ),
      for (final search in searches)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.history_rounded,
            color: AppIconColors.standard,
          ),
          title: Text(
            search.query,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: Color(0xFF17171B)),
          ),
          onTap: () => onSelect(search.query),
          trailing: IconButton(
            tooltip: AppSettingsScope.translate(
              context,
              "customer.remove_value0.3028bf7d",
              args: {"value0": search.query},
            ),
            onPressed: () => onRemove(search.query),
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppIconColors.standard,
            ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0EDF0)),
        boxShadow: [
          BoxShadow(
            color: searchWine.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (suggestion)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5E8EC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      result.isVendor
                          ? Icons.storefront_outlined
                          : Icons.search_rounded,
                      color: searchWine,
                      size: 22,
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
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
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF17171B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF73737D),
                        ),
                      ),
                      if (!suggestion) ...[
                        const SizedBox(height: 6),
                        Text(
                          result.isVendor
                              ? '${item.data['completed_count'] ?? 0} completed events'
                              : result.priceLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            color: searchWine,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (item.rating != null)
                          Text(
                            AppSettingsScope.translate(
                              context,
                              "customer.value0_value1_reviews.c2e1d396",
                              args: {
                                "value0": item.rating!.toStringAsFixed(1),
                                "value1": item.data['review_count'],
                              },
                            ),
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
                    tooltip: AppSettingsScope.translate(
                      context,
                      "customer.search_value0.f834f781",
                      args: {"value0": result.name},
                    ),
                    onPressed: onFill,
                    icon: const Icon(
                      Icons.north_west_rounded,
                      size: 19,
                      color: AppIconColors.standard,
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: AppIconColors.standard,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => ColoredBox(
    color: const Color(0xFFF5E8EC),
    child: Icon(
      result.isVendor ? Icons.storefront_outlined : Icons.event_outlined,
      color: searchWine,
      size: 28,
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
              selectedColor: const Color(0xFFF5E8EC),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: selected == entry.key
                      ? searchWine
                      : const Color(0xFFF0EDF0),
                ),
              ),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: selected == entry.key
                    ? searchWine
                    : const Color(0xFF73737D),
              ),
            ),
          ),
      ],
    ),
  );
}
