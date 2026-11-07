import '../../widgets/vendor_page_scaffold.dart';

import 'package:flutter/material.dart';

import '../../widgets/reviews/service_review_summary.dart';

import '../../models/service_model.dart';
import '../../widgets/listings/listing_ui.dart';

class ListingDetailScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    String t(String en, String ta) => listingText(context, en, ta);
    final colors = Theme.of(context).colorScheme;
    Widget section(String title, Widget content) => Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            content,
          ],
        ),
      ),
    );
    return VendorPageScaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(title: Text(t('Service Details', 'சேவை விவரங்கள்'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (service.gallery.isEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
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
                    borderRadius: BorderRadius.circular(18),
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
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${i + 1} / ${service.gallery.length}',
                              style: const TextStyle(color: Colors.white),
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
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: ListingStatusBadge(active: service.isActive),
          ),
          const SizedBox(height: 12),
          Text(
            service.priceLabel,
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            t(service.pricing.type.label, service.pricing.type.tamilLabel),
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (onEdit != null)
                FilledButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(t('Edit service', 'சேவையைத் திருத்து')),
                ),
              if (onManageImages != null)
                OutlinedButton.icon(
                  onPressed: onManageImages,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(t('Manage photos', 'படங்களை நிர்வகி')),
                ),
            ],
          ),
          const SizedBox(height: 20),
          section(
            t('Description', 'விளக்கம்'),
            Text(
              service.description?.trim().isNotEmpty == true
                  ? service.description!
                  : t('No description added.', 'விளக்கம் சேர்க்கப்படவில்லை.'),
            ),
          ),
          section(
            t('Listing information', 'பட்டியல் தகவல்கள்'),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (service.categoryName != null)
                  Text('${t('Category', 'வகை')}: ${service.categoryName}'),
                const SizedBox(height: 8),
                SelectableText('${t('Service ID', 'சேவை எண்')}: ${service.id}'),
                const SizedBox(height: 8),
                Text(
                  '${t('Created', 'உருவாக்கப்பட்டது')}: ${MaterialLocalizations.of(context).formatMediumDate(service.createdAt.toLocal())}',
                ),
              ],
            ),
          ),
          section(
            t('Manage service', 'சேவையை நிர்வகி'),
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
                          ? t('Deactivate', 'செயலிழக்கச் செய்')
                          : t('Activate', 'செயல்படுத்து'),
                    ),
                    onTap: onToggleStatus,
                  ),
                if (onPromote != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.campaign_outlined),
                    title: Text(t('Promote', 'விளம்பரப்படுத்து')),
                    onTap: onPromote,
                  ),
                if (onDuplicate != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.copy_outlined),
                    title: Text(t('Duplicate', 'நகல் எடு')),
                    onTap: onDuplicate,
                  ),
                if (onDelete != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline, color: colors.error),
                    title: Text(
                      t('Delete service', 'சேவையை நீக்கு'),
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
