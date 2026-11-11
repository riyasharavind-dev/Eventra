import 'package:flutter/material.dart';

import '../../models/vendor_tour_step.dart';
import '../../repositories/onboarding_repository.dart';
import '../../services/vendor_tour_controller.dart';

/// Entry point retained for existing callers; the guide runs over actual screens.
abstract final class VendorTrialScreen {
  static Future<void> open(
    BuildContext context, {
    bool restart = false,
    OnboardingRepository? repository,
    VendorGuideProgress? initialProgress,
  }) async {
    FocusScope.of(context).unfocus();
    await VendorTourController.instance.start(
      repository: repository,
      restart: restart,
      progress: initialProgress,
    );
  }
}
