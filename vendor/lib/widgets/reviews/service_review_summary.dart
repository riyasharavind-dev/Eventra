import '../common/app_shimmer.dart';

import 'package:flutter/material.dart';

import '../../models/service_review_model.dart';
import '../../repositories/review_repository.dart';
import '../../screens/extended/service_reviews_screen.dart';

class ServiceReviewSummary extends StatefulWidget {
  final String serviceId;
  final bool vendorMode;
  final ReviewRepository? repository;
  const ServiceReviewSummary({
    super.key,
    required this.serviceId,
    this.vendorMode = false,
    this.repository,
  });
  @override
  State<ServiceReviewSummary> createState() => _ServiceReviewSummaryState();
}

class _ServiceReviewSummaryState extends State<ServiceReviewSummary> {
  late final ReviewRepository repo;
  late Future<ReviewSummary> loading;
  @override
  void initState() {
    super.initState();
    repo = widget.repository ?? ReviewRepository();
    loading = repo.summary(serviceId: widget.serviceId);
  }

  @override
  void didUpdateWidget(covariant ServiceReviewSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serviceId != widget.serviceId) {
      loading = repo.summary(serviceId: widget.serviceId);
    }
  }

  void refresh() {
    setState(() {
      loading = repo.summary(serviceId: widget.serviceId);
    });
  }

  Future<void> open() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ServiceReviewsScreen(
          serviceId: widget.serviceId,
          vendorMode: widget.vendorMode,
          repository: repo,
        ),
      ),
    );
    if (mounted) {
      refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tamil = Localizations.localeOf(context).languageCode == 'ta';
    return FutureBuilder<ReviewSummary>(
      future: loading,
      builder: (context, snapshot) => Card(
        child: ListTile(
          leading: Icon(
            Icons.star_outline,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(
            tamil ? 'மதிப்பீடு மற்றும் விமர்சனங்கள்' : 'Ratings & reviews',
          ),
          subtitle: Text(
            snapshot.hasError
                ? (tamil
                      ? 'ஏற்ற முடியவில்லை. மீண்டும் முயற்சிக்கவும்.'
                      : 'Unable to load. Tap to retry.')
                : !snapshot.hasData
                ? (tamil ? 'ஏற்றுகிறது…' : 'Loading…')
                : snapshot.data!.count == 0
                ? (tamil ? 'இன்னும் விமர்சனங்கள் இல்லை' : 'No reviews yet')
                : '${snapshot.data!.average!.toStringAsFixed(1)} / 5 · ${snapshot.data!.count} ${tamil ? 'விமர்சனங்கள்' : 'reviews'}',
          ),
          trailing: snapshot.connectionState == ConnectionState.waiting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: AppShimmerIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          onTap: snapshot.hasError ? refresh : open,
        ),
      ),
    );
  }
}
