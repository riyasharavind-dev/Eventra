import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:flutter/material.dart';

import '../../repositories/review_repository.dart';
import '../../widgets/reviews/service_reviews_list.dart';

class ServiceReviewsScreen extends StatelessWidget {
  const ServiceReviewsScreen({
    super.key,
    required this.serviceId,
    this.repository,
  });
  final String serviceId;
  final ReviewRepository? repository;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F8FA),
    appBar: AppBar(
      title: Text(
        AppSettingsScope.translate(
          context,
          "customer.customer_reviews.8f8b1729",
        ),
      ),
    ),
    body: ServiceReviewsList(serviceId: serviceId, repository: repository),
  );
}
