import 'package:flutter/material.dart';

import '../../repositories/review_repository.dart';
import 'service_reviews_screen.dart';

/// Vendor-wide customer reviews, reusing the existing scoped review workflow.
class CustomerReviewsScreen extends StatelessWidget {
  final ReviewRepository? repository;
  const CustomerReviewsScreen({super.key, this.repository});

  @override
  Widget build(BuildContext context) =>
      ServiceReviewsScreen(vendorMode: true, repository: repository);
}
