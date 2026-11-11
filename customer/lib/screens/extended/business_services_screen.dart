import 'package:flutter/material.dart';

import '../../repositories/home_feed_repository.dart';
import '../../widgets/home_feed_widgets.dart';

/// Only services belonging to this business; vendor's other businesses excluded.
class BusinessServicesScreen extends StatelessWidget {
  const BusinessServicesScreen({
    super.key,
    required this.businessId,
    required this.businessName,
  });
  final String businessId, businessName;
  @override
  Widget build(BuildContext context) => HomeFeedResultsScreen(
    title: businessName,
    businessId: businessId,
    repository: HomeFeedRepository(),
  );
}
