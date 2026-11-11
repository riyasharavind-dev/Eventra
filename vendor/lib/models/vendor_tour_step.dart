class VendorGuideProgress {
  const VendorGuideProgress({
    this.status = 'pending',
    this.step = 0,
    this.synced = true,
  });
  final String status;
  final int step;
  final bool synced;
  bool get shouldOffer => status == 'pending' || status == 'in_progress';
  factory VendorGuideProgress.fromMap(
    Map<String, dynamic> map, {
    bool synced = true,
  }) {
    final status = map['status'];
    final step = map['last_step'];
    if (!const [
          'pending',
          'in_progress',
          'skipped',
          'completed',
        ].contains(status) ||
        step is! int ||
        step < 0 ||
        step > 6 ||
        (status == 'completed' && step != 6)) {
      throw const FormatException('Invalid guide progress');
    }
    return VendorGuideProgress(
      status: status as String,
      step: step,
      synced: synced,
    );
  }
  Map<String, dynamic> toMap() => {
    'status': status,
    'last_step': step,
    'guide_version': 1,
  };
}

class VendorSetupChecklist {
  const VendorSetupChecklist({
    required this.profileComplete,
    required this.businessCount,
    required this.serviceCount,
  });
  final bool profileComplete;
  final int businessCount, serviceCount;
  int get completed =>
      (profileComplete ? 1 : 0) +
      (businessCount > 0 ? 1 : 0) +
      (serviceCount > 0 ? 1 : 0);
  factory VendorSetupChecklist.fromMap(Map<String, dynamic> map) =>
      VendorSetupChecklist(
        profileComplete: map['profile_complete'] == true,
        businessCount: (map['business_count'] as num).toInt(),
        serviceCount: (map['service_count'] as num).toInt(),
      );
}
