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

class VendorTourStep {
  const VendorTourStep(this.title, this.tamilTitle, this.body, this.tamilBody);
  final String title, tamilTitle, body, tamilBody;
  static const steps = [
    VendorTourStep(
      'Your dashboard',
      'உங்கள் டாஷ்போர்டு',
      'See booking updates and your business overview here. Tap Listings below to explore your services.',
      'முன்பதிவு நிலவரத்தை இங்கே பார்க்கலாம். சேவைகளைப் பார்க்க கீழே Listings என்பதைத் தொடவும்.',
    ),
    VendorTourStep(
      'Your listings',
      'உங்கள் சேவைகள்',
      'This is where your services appear. Tap the + button to see what you can add.',
      'உங்கள் சேவைகள் இங்கே தோன்றும். புதிதாகச் சேர்க்க + பொத்தானைத் தொடவும்.',
    ),
    VendorTourStep(
      'Choose what to add',
      'எதைச் சேர்ப்பது?',
      'Add a business first, then add its services with photos and pricing. Tap Add a business.',
      'முதலில் வணிகம், பின்னர் படங்கள் மற்றும் விலையுடன் சேவைகளைச் சேர்க்கலாம். Add a business என்பதைத் தொடவும்.',
    ),
    VendorTourStep(
      'Try a sample business',
      'மாதிரி வணிகம்',
      'A business needs a name, one parent category and its shop location. Try this short sample; nothing is published.',
      'வணிகப் பெயர், ஒரு முதன்மை வகை, கடை இருப்பிடம் தேவை. இந்த மாதிரி விவரங்கள் வெளியிடப்படாது.',
    ),
    VendorTourStep(
      'Handle a booking',
      'முன்பதிவைப் பயிற்சி செய்யுங்கள்',
      'Open the sample request, check its details, then try accepting or rejecting it. Calendar shows events and past history by date.',
      'மாதிரி கோரிக்கையின் விவரங்களைப் பார்த்து ஏற்க அல்லது நிராகரிக்க முயற்சிக்கவும். நாட்காட்டியில் தேதிவாரியாக நிகழ்வுகளையும் வரலாற்றையும் பார்க்கலாம்.',
    ),
    VendorTourStep(
      'Profile and settings',
      'சுயவிவரம் மற்றும் அமைப்புகள்',
      'Me contains your profile, businesses, reviews and help. Tap App Settings to learn about notifications and language.',
      'Me பகுதியில் சுயவிவரம், வணிகங்கள், மதிப்புரைகள் மற்றும் உதவி உள்ளன. App Settings என்பதைத் தொடவும்.',
    ),
  ];
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
