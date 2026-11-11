import 'package:eventor_vendor/services/app_settings_controller.dart';

import '../../services/app_live_data.dart';
import '../../repositories/service_repository.dart';
import '../../widgets/vendor_page_scaffold.dart';

import 'package:flutter/material.dart';

import '../../widgets/reviews/service_review_summary.dart';

import '../../models/service_model.dart';
import '../../widgets/listings/listing_ui.dart';

class ListingDetailScreen extends StatefulWidget {
  final ServiceModel service;
  final VoidCallback? onEdit,
      onToggleStatus,
      onDelete,
      onPromote,
      onDuplicate,
      onManageImages;
  const ListingDetailScreen({
    super.key,
    required this.service,
    this.onEdit,
    this.onToggleStatus,
    this.onDelete,
    this.onPromote,
    this.onDuplicate,
    this.onManageImages,
  });
  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen>
    with LiveDataState<ListingDetailScreen> {
  late ServiceModel service;
  bool available = true;
  @override
  Set<String> get liveDatasets => {'own:services', 'public:category_nodes'};
  @override
  void initState() {
    super.initState();
    service = widget.service;
  }

  @override
  Future<void> onLiveData(Set<String> changed) async {
    final fresh = await ServiceRepository().getServiceById(service.id);
    if (!mounted) return;
    setState(() {
      available = fresh != null;
      if (fresh != null) service = fresh;
    });
  }

  VoidCallback? get onEdit => widget.onEdit;
  VoidCallback? get onToggleStatus => widget.onToggleStatus;
  VoidCallback? get onDelete => widget.onDelete;
  VoidCallback? get onPromote => widget.onPromote;
  VoidCallback? get onDuplicate => widget.onDuplicate;
  VoidCallback? get onManageImages => widget.onManageImages;
  @override
  Widget build(BuildContext context) {
    String t(String en) => AppSettingsScope.source(context, en);
    final colors = Theme.of(context).colorScheme;
    const wine = Color(0xFF80152C);

    Widget section(String title, Widget content) => Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0EDF0)),
        boxShadow: [
          BoxShadow(
            color: wine.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF17171B),
            ),
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
    if (!available) {
      return VendorPageScaffold(
        appBar: AppBar(
          title: Text(
            AppSettingsScope.translate(
              context,
              "vendor.service_details.3028f307",
            ),
          ),
        ),
        body: Center(
          child: Text(
            AppSettingsScope.translate(
              context,
              "vendor.this_service_is_no_longer_available.bf16bb61",
            ),
          ),
        ),
      );
    }
    return VendorPageScaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        title: Text(
          AppSettingsScope.translate(
            context,
            "vendor.service_details.3028f307",
          ),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (service.gallery.isEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: listingPhoto(null, width: double.infinity, height: 230),
            )
          else
            SizedBox(
              height: 260,
              child: PageView.builder(
                itemCount: service.gallery.length,
                itemBuilder: (c, i) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        listingPhoto(service.gallery[i], height: 260),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${i + 1} / ${service.gallery.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 18),
          ServiceReviewSummary(serviceId: service.id, vendorMode: true),
          Text(
            service.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF17171B),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: ListingStatusBadge(active: service.isActive),
          ),
          const SizedBox(height: 14),
          Text(
            service.priceLabel,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: wine,
            ),
          ),
          Text(
            t(service.pricing.type.label),
            style: const TextStyle(color: Color(0xFF73737D), fontSize: 13),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (onEdit != null)
                FilledButton.icon(
                  onPressed: onEdit,
                  style: FilledButton.styleFrom(
                    backgroundColor: wine,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(
                    AppSettingsScope.translate(
                      context,
                      "vendor.edit_service.3b3ed7a7",
                    ),
                  ),
                ),
              if (onManageImages != null)
                OutlinedButton.icon(
                  onPressed: onManageImages,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: wine,
                    side: const BorderSide(color: wine),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text(
                    AppSettingsScope.translate(
                      context,
                      "vendor.manage_photos.6d385d88",
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          section(
            AppSettingsScope.translate(context, "vendor.description.526e0087"),
            Text(
              service.description?.trim().isNotEmpty == true
                  ? service.description!
                  : AppSettingsScope.translate(
                      context,
                      "vendor.no_description_added.0b1efa8a",
                    ),
            ),
          ),
          section(
            AppSettingsScope.translate(
              context,
              "vendor.listing_information.b6100e2d",
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (service.categoryName != null)
                  Text(
                    '${AppSettingsScope.translate(context, "vendor.category.292c06f0")}: ${service.categoryName}',
                  ),
                const SizedBox(height: 8),
                SelectableText(
                  '${AppSettingsScope.translate(context, "vendor.service_id.a4bd8b91")}: ${service.id}',
                ),
                const SizedBox(height: 8),
                Text(
                  '${AppSettingsScope.translate(context, "vendor.created.d70b9e24")}: ${MaterialLocalizations.of(context).formatMediumDate(service.createdAt.toLocal())}',
                ),
              ],
            ),
          ),
          section(
            AppSettingsScope.translate(
              context,
              "vendor.manage_service.a23b096c",
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (onToggleStatus != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      service.isActive
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                    ),
                    title: Text(
                      service.isActive
                          ? AppSettingsScope.translate(
                              context,
                              "vendor.deactivate.fb1e6fa5",
                            )
                          : AppSettingsScope.translate(
                              context,
                              "vendor.activate.24433c70",
                            ),
                    ),
                    onTap: onToggleStatus,
                  ),
                if (onPromote != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.campaign_outlined),
                    title: Text(
                      AppSettingsScope.translate(
                        context,
                        "vendor.promote.5834dab0",
                      ),
                    ),
                    onTap: onPromote,
                  ),
                if (onDuplicate != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.copy_outlined),
                    title: Text(
                      AppSettingsScope.translate(
                        context,
                        "vendor.duplicate.02cdaabf",
                      ),
                    ),
                    onTap: onDuplicate,
                  ),
                if (onDelete != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline, color: colors.error),
                    title: Text(
                      AppSettingsScope.translate(
                        context,
                        "vendor.delete_service.9f0f483f",
                      ),
                      style: TextStyle(color: colors.error),
                    ),
                    onTap: onDelete,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
