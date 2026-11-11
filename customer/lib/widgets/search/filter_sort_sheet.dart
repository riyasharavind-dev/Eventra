import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:eventor_customer/core/theme/app_icon_colors.dart';
import 'package:flutter/material.dart';

const customerSearchSorts = <String, String>{
  'relevance': 'Recommended',
  'price_low': 'Price: Low to High',
  'price_high': 'Price: High to Low',
  'rating': 'Top rated',
  'newest': 'Newest first',
};

class SearchFilterSelection {
  final String type, category, sort, status;
  const SearchFilterSelection({
    this.type = 'all',
    this.category = 'all',
    this.sort = 'relevance',
    this.status = 'all',
  });
}

Future<SearchFilterSelection?> showSearchFilterSortSheet(
  BuildContext context, {
  required SearchFilterSelection selection,
  required Map<String, String> typeOptions,
  required Map<String, String> categoryOptions,
}) {
  FocusScope.of(context).unfocus();
  return showModalBottomSheet<SearchFilterSelection>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (_) => SearchFilterSortSheet(
      selection: selection,
      typeOptions: typeOptions,
      categoryOptions: categoryOptions,
      showCategory: false,
      showStatus: false,
      sortOptions: customerSearchSorts,
    ),
  );
}

class SearchFilterSortSheet extends StatefulWidget {
  final Map<String, String>? statusOptions, sortOptions;
  final String? categoryLabel;
  final bool showCategory, showStatus;
  final String defaultSort;
  final Widget? additionalFilters;
  final VoidCallback? onReset;
  final bool canApply;
  final SearchFilterSelection selection;
  final Map<String, String> typeOptions, categoryOptions;
  const SearchFilterSortSheet({
    super.key,
    this.statusOptions,
    this.sortOptions,
    this.categoryLabel,
    this.showCategory = true,
    this.showStatus = true,
    this.defaultSort = 'relevance',
    this.additionalFilters,
    this.onReset,
    this.canApply = true,
    required this.selection,
    required this.typeOptions,
    required this.categoryOptions,
  });
  @override
  State<SearchFilterSortSheet> createState() => _SearchFilterSortSheetState();
}

class _SearchFilterSortSheetState extends State<SearchFilterSortSheet> {
  static const wine = Color(0xFF80152C);
  late String chosenType, chosenCategory, chosenSort, chosenStatus;
  String t(String english) =>
      AppSettingsScope.of(context).text(english, english);
  @override
  void initState() {
    super.initState();
    chosenType = widget.typeOptions.containsKey(widget.selection.type)
        ? widget.selection.type
        : 'all';
    chosenCategory =
        widget.categoryOptions.containsKey(widget.selection.category)
        ? widget.selection.category
        : 'all';
    chosenSort = widget.selection.sort;
    chosenStatus = widget.selection.status;
  }

  void reset() {
    chosenType = 'all';
    chosenCategory = 'all';
    chosenSort = widget.defaultSort;
    chosenStatus = 'all';
    widget.onReset?.call();
  }

  String _statusLabel(String value) => switch (value) {
    'active' => AppSettingsScope.of(context).text("Active", "செயலில்"),
    'archived' => AppSettingsScope.of(context).text("Archived", "காப்பகத்தில்"),
    'inactive' => AppSettingsScope.of(context).text("Inactive", "செயலற்றது"),
    _ => AppSettingsScope.of(context).text("All", "அனைத்தும்"),
  };
  @override
  Widget build(BuildContext context) {
    Widget field(IconData icon, String title, Widget input) => Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF5E8EC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppIconColors.standard, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF17171B),
                  ),
                ),
                const SizedBox(height: 9),
                input,
              ],
            ),
          ),
        ],
      ),
    );
    Widget dropdown(
      String label,
      String value,
      Map<String, String> options,
      ValueChanged<String> changed,
    ) => DropdownButtonFormField<String>(
      key: ValueKey('filter-$label-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFF0EDF0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFF0EDF0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: wine, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      items: options.entries
          .map(
            (e) => DropdownMenuItem(
              value: e.key,
              child: Text(
                e.value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => changed(v));
      },
    );
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: AppSettingsScope.of(context).text("Close", "மூடு"),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                  Expanded(
                    child: Text(
                      AppSettingsScope.of(context)
                          .text("Filter & Sort", "வடிகட்டி வரிசைப்படுத்து"),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(reset),
                    child: Text(
                      AppSettingsScope.of(context)
                          .text("Clear All", "அனைத்தையும் அழி"),
                      style: const TextStyle(
                        color: wine,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                AppSettingsScope.of(context).text(
                  "Find exactly what you're looking for",
                  "தேவையான சேவைகளை எளிதில் கண்டறியுங்கள்",
                ),
                style: const TextStyle(color: Color(0xFF7B8194), fontSize: 12),
              ),
              const SizedBox(height: 25),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      field(
                        Icons.category_outlined,
                        AppSettingsScope.of(context)
                            .text("Result type", "முடிவு வகை"),
                        dropdown(
                          'type',
                          chosenType,
                          widget.typeOptions,
                          (v) => chosenType = v,
                        ),
                      ),
                      if (widget.showCategory)
                        field(
                          Icons.sell_rounded,
                          widget.categoryLabel ??
                              AppSettingsScope.of(context)
                                  .text("Category", "வகை"),
                          dropdown(
                            'category',
                            chosenCategory,
                            widget.categoryOptions,
                            (v) => chosenCategory = v,
                          ),
                        ),
                      if (widget.showStatus)
                        field(
                          Icons.pie_chart_rounded,
                          AppSettingsScope.of(context).text("Status", "நிலை"),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              for (final s
                                  in (widget.statusOptions?.keys ??
                                      [
                                        'all',
                                        'active',
                                        'inactive',
                                        'archived',
                                      ]))
                                ChoiceChip(
                                  label: Text(
                                    widget.statusOptions?[s] ?? _statusLabel(s),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: chosenStatus == s
                                          ? wine
                                          : const Color(0xFF282837),
                                    ),
                                  ),
                                  selected: chosenStatus == s,
                                  showCheckmark: false,
                                  selectedColor: const Color(0xFFFFF2F5),
                                  backgroundColor: const Color(0xFFF5F5F8),
                                  side: BorderSide(
                                    color: chosenStatus == s
                                        ? wine
                                        : Colors.transparent,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  onSelected: (_) =>
                                      setState(() => chosenStatus = s),
                                ),
                            ],
                          ),
                        ),
                      if (widget.additionalFilters != null)
                        widget.additionalFilters!,
                      field(
                        Icons.sort_rounded,
                        AppSettingsScope.of(context).text("Sort by", "வரிசை"),
                        dropdown(
                          'sort',
                          chosenSort,
                          widget.sortOptions ??
                              {
                                'newest': AppSettingsScope.of(context)
                                    .text("Newest first", "புதியவை முதலில்"),
                                'price_low': AppSettingsScope.of(context).text(
                                  "Price · low to high",
                                  "விலை · குறைவிலிருந்து அதிகம்",
                                ),
                                'price_high': AppSettingsScope.of(context).text(
                                  "Price · high to low",
                                  "விலை · அதிகத்திலிருந்து குறைவு",
                                ),
                                'name': AppSettingsScope.of(context)
                                    .text("Service name", "சேவையின் பெயர்"),
                              },
                          (v) => chosenSort = v,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: wine,
                        side: const BorderSide(color: wine),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      onPressed: () => setState(reset),
                      child: Text(
                        AppSettingsScope.of(context).text("Reset", "மீட்டமை"),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: wine,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      onPressed: !widget.canApply
                          ? null
                          : () {
                              Navigator.pop(
                                context,
                                SearchFilterSelection(
                                  type: chosenType,
                                  category: chosenCategory,
                                  sort: chosenSort,
                                  status: chosenStatus,
                                ),
                              );
                            },
                      child: Text(
                        AppSettingsScope.of(context)
                            .text("Apply Filters", "பயன்படுத்து"),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
