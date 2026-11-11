import 'package:eventor_vendor/services/app_settings_controller.dart';
import 'package:eventor_vendor/core/theme/app_icon_colors.dart';
import 'package:flutter/material.dart';

class ListingFilterSelection {
  final String business, category, sort, status;
  const ListingFilterSelection({
    this.business = 'all',
    this.category = 'all',
    this.sort = 'newest',
    this.status = 'all',
  });
}

Future<ListingFilterSelection?> showListingFilterSheet(
  BuildContext context, {
  required ListingFilterSelection selection,
  required Map<String, String> businessOptions,
  required Map<String, String> categoryOptions,
}) {
  FocusScope.of(context).unfocus();
  return showModalBottomSheet<ListingFilterSelection>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (_) => ListingFilterSheet(
      selection: selection,
      businessOptions: businessOptions,
      categoryOptions: categoryOptions,
    ),
  );
}

class ListingFilterSheet extends StatefulWidget {
  final Map<String, String>? statusOptions, sortOptions;
  final String? categoryLabel;
  final bool showCategory, showStatus;
  final String defaultSort;
  final Widget? additionalFilters;
  final VoidCallback? onReset;
  final bool canApply;
  final ListingFilterSelection selection;
  final Map<String, String> businessOptions, categoryOptions;
  const ListingFilterSheet({
    super.key,
    this.statusOptions,
    this.sortOptions,
    this.categoryLabel,
    this.showCategory = true,
    this.showStatus = true,
    this.defaultSort = 'newest',
    this.additionalFilters,
    this.onReset,
    this.canApply = true,
    required this.selection,
    required this.businessOptions,
    required this.categoryOptions,
  });
  @override
  State<ListingFilterSheet> createState() => _ListingFilterSheetState();
}

class _ListingFilterSheetState extends State<ListingFilterSheet> {
  static const wine = Color(0xFF80152C);
  late String chosenBusiness, chosenCategory, chosenSort, chosenStatus;
  String t(String english) => AppSettingsScope.source(context, english);
  @override
  void initState() {
    super.initState();
    chosenBusiness =
        widget.businessOptions.containsKey(widget.selection.business)
        ? widget.selection.business
        : 'all';
    chosenCategory =
        widget.categoryOptions.containsKey(widget.selection.category)
        ? widget.selection.category
        : 'all';
    chosenSort = widget.selection.sort;
    chosenStatus = widget.selection.status;
  }

  void reset() {
    chosenBusiness = 'all';
    chosenCategory = 'all';
    chosenSort = widget.defaultSort;
    chosenStatus = 'all';
    widget.onReset?.call();
  }

  String _statusLabel(String value) => switch (value) {
    'active' => AppSettingsScope.translate(context, "vendor.active.92340695"),
    'archived' => AppSettingsScope.translate(context, 'listing.archived'),
    'inactive' => AppSettingsScope.translate(
      context,
      "vendor.inactive.ac7c949f",
    ),
    _ => AppSettingsScope.translate(context, "vendor.all.a52ace42"),
  };
  @override
  Widget build(BuildContext context) {
    Widget field(IconData icon, String title, Widget input) => Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFFF5E8EC),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppIconColors.standard, size: 23),
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
                    fontSize: 13,
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFDFE1E9)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
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
                    tooltip: AppSettingsScope.translate(
                      context,
                      "vendor.close.7d9eb7ac",
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                  Expanded(
                    child: Text(
                      AppSettingsScope.translate(
                        context,
                        "vendor.filter_sort.8d76c3b1",
                      ),
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
                      AppSettingsScope.translate(
                        context,
                        "vendor.clear_all.ddceb7ad",
                      ),
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
                AppSettingsScope.translate(
                  context,
                  "vendor.find_exactly_what_you_re_looking_for.656bff86",
                ),
                style: const TextStyle(color: Color(0xFF7B8194), fontSize: 12),
              ),
              const SizedBox(height: 25),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      field(
                        Icons.storefront_rounded,
                        AppSettingsScope.translate(
                          context,
                          "vendor.business.76f68a75",
                        ),
                        dropdown(
                          'business',
                          chosenBusiness,
                          widget.businessOptions,
                          (v) => chosenBusiness = v,
                        ),
                      ),
                      if (widget.showCategory)
                        field(
                          Icons.sell_rounded,
                          widget.categoryLabel ??
                              AppSettingsScope.translate(
                                context,
                                "vendor.category.292c06f0",
                              ),
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
                          AppSettingsScope.translate(
                            context,
                            "vendor.status.920e413c",
                          ),
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
                        AppSettingsScope.translate(
                          context,
                          "vendor.sort_by.c9129025",
                        ),
                        dropdown(
                          'sort',
                          chosenSort,
                          widget.sortOptions ??
                              {
                                'newest': AppSettingsScope.translate(
                                  context,
                                  "vendor.newest_first.ffb6f576",
                                ),
                                'price_low': AppSettingsScope.translate(
                                  context,
                                  "vendor.price_low_to_high.6e679339",
                                ),
                                'price_high': AppSettingsScope.translate(
                                  context,
                                  "vendor.price_high_to_low.0dd9944a",
                                ),
                                'name': AppSettingsScope.translate(
                                  context,
                                  "vendor.service_name.1bb8870c",
                                ),
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
                        AppSettingsScope.translate(
                          context,
                          "vendor.reset.daee7606",
                        ),
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
                                ListingFilterSelection(
                                  business: chosenBusiness,
                                  category: chosenCategory,
                                  sort: chosenSort,
                                  status: chosenStatus,
                                ),
                              );
                            },
                      child: Text(
                        AppSettingsScope.translate(
                          context,
                          "vendor.apply_filters.09b2e220",
                        ),
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
