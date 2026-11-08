import '../../widgets/common/app_shimmer.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_icon_colors.dart';
import '../../models/vendor_tour_step.dart';
import '../../repositories/onboarding_repository.dart';
import '../../services/app_settings_controller.dart';
import '../../services/vendor_navigation_controller.dart';
import '../../widgets/trial/tour_overlay.dart';
import '../../widgets/trial/tour_instruction_card.dart';
import 'booking_practice_screen.dart';

/// Interactive, isolated previews. Only learning progress is written remotely.
class VendorTrialScreen extends StatefulWidget {
  const VendorTrialScreen({
    super.key,
    this.repository,
    this.restart = false,
    this.initialProgress,
  });
  final OnboardingRepository? repository;
  final bool restart;
  final VendorGuideProgress? initialProgress;
  static Future<void> open(
    BuildContext context, {
    bool restart = false,
    OnboardingRepository? repository,
    VendorGuideProgress? initialProgress,
  }) => showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    routeSettings: const RouteSettings(
      name: VendorNavigationController.guideRouteName,
    ),
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => VendorTrialScreen(
      repository: repository,
      restart: restart,
      initialProgress: initialProgress,
    ),
    transitionBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
  @override
  State<VendorTrialScreen> createState() => _VendorTrialScreenState();
}

class _VendorTrialScreenState extends State<VendorTrialScreen> {
  late final _repository = widget.repository ?? OnboardingRepository();
  final _target = GlobalKey();
  final _name = TextEditingController(text: 'My sample business');
  final _shop = TextEditingController(text: 'Sample shop, Chennai');
  final _form = GlobalKey<FormState>();
  int _step = 0;
  bool _moving = false;
  bool _loading = true,
      _closing = false,
      _allowPop = false,
      _localOnly = false,
      _practicing = false;
  String _category = 'Decoration';
  String t(String en, String ta) => AppSettingsScope.of(context).text(en, ta);
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.restart) {
        final synced = await _repository.saveProgress(
          const VendorGuideProgress(status: 'in_progress'),
          restart: true,
        );
        _localOnly = !synced;
      } else {
        final progress =
            widget.initialProgress ?? await _repository.loadProgress();
        _step = progress.step;
        _localOnly = !progress.synced;
      }
    } catch (_) {
      _localOnly = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _record(int step, String status) async {
    try {
      final synced = await _repository.saveProgress(
        VendorGuideProgress(status: status, step: step),
      );
      if (mounted) setState(() => _localOnly = !synced);
    } catch (_) {
      if (mounted) setState(() => _localOnly = true);
    }
  }

  void _advance() {
    if (_closing || _moving || _step >= 6) return;
    if (_step == 3 && !(_form.currentState?.validate() ?? false)) return;
    _moving = true;
    setState(() => _step++);
    WidgetsBinding.instance.addPostFrameCallback((_) => _moving = false);
    unawaited(_record(_step, _step == 6 ? 'completed' : 'in_progress'));
  }

  Future<void> _practice() async {
    if (_practicing) return;
    _practicing = true;
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const BookingPracticeScreen()),
    );
    _practicing = false;
    if (mounted && done == true) _advance();
  }

  Future<void> _exit() async {
    if (_closing) return;
    setState(() => _closing = true);
    await _record(_step, _step == 6 ? 'completed' : 'skipped');
    if (!mounted) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _name.dispose();
    _shop.dispose();
    super.dispose();
  }

  Widget _tile(
    IconData icon,
    String title, {
    VoidCallback? onTap,
    Key? key,
    String? subtitle,
  }) => Card(
    key: key,
    child: ListTile(
      leading: Icon(icon, color: AppIconColors.standard),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
  Widget _sampleHeading(String title) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      title,
      style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
    ),
  );
  Widget _preview() {
    final content = switch (_step) {
      0 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sampleHeading(t('Dashboard', 'டாஷ்போர்டு')),
          Text(
            t(
              'Your booking and business overview',
              'முன்பதிவு மற்றும் வணிக நிலவரம்',
            ),
          ),
          const SizedBox(height: 20),
          _tile(
            Icons.event_note_outlined,
            t('2 sample requests', '2 மாதிரி கோரிக்கைகள்'),
          ),
          _tile(
            Icons.storefront_outlined,
            t('Your businesses', 'உங்கள் வணிகங்கள்'),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: _target,
            onPressed: _advance,
            icon: const Icon(Icons.format_list_bulleted),
            label: Text(t('Listings', 'சேவைகள்')),
          ),
        ],
      ),
      1 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sampleHeading(t('Listings', 'சேவைகள்')),
          _tile(
            Icons.photo_library_outlined,
            t('Sample wedding decoration', 'மாதிரி திருமண அலங்காரம்'),
            subtitle: t(
              'Photos, description and pricing',
              'படங்கள், விவரம் மற்றும் விலை',
            ),
          ),
          const SizedBox(height: 36),
          Align(
            alignment: Alignment.centerRight,
            child: FloatingActionButton(
              key: _target,
              heroTag: 'trial-add',
              onPressed: _advance,
              backgroundColor: const Color(0xFF80152C),
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
      2 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sampleHeading(t('Listings', 'சேவைகள்')),
          const SizedBox(height: 12),
          _tile(
            Icons.storefront_outlined,
            t('Add a business', 'வணிகம் சேர்'),
            key: _target,
            onTap: _advance,
          ),
          _tile(
            Icons.add_business_outlined,
            t('Add a service', 'சேவை சேர்'),
            subtitle: t(
              'Choose its business, photos and pricing',
              'வணிகம், படங்கள் மற்றும் விலையைத் தேர்வு செய்யுங்கள்',
            ),
          ),
        ],
      ),
      3 => Form(
        key: _form,
        child: Column(
          key: _target,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sampleHeading(t('Sample business', 'மாதிரி வணிகம்')),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(
                labelText: t('Business name', 'வணிகப் பெயர்'),
              ),
              validator: (v) => (v?.trim().length ?? 0) < 2
                  ? t('Enter a business name', 'வணிகப் பெயரை எழுதவும்')
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: t('One parent category', 'ஒரு முதன்மை வகை'),
              ),
              items: const [
                'Decoration',
                'Photography',
                'Catering',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) {
                if (v != null) _category = v;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _shop,
              decoration: InputDecoration(
                labelText: t('Sample shop address', 'மாதிரி கடை முகவரி'),
              ),
              validator: (v) => (v?.trim().isEmpty ?? true)
                  ? t('Enter a sample address', 'மாதிரி முகவரி எழுதவும்')
                  : null,
            ),
            const SizedBox(height: 14),
            Text(
              t(
                'In the real form, select State → District → Subdistrict and pin your shop on the map.',
                'உண்மையான படிவத்தில் மாநிலம் → மாவட்டம் → வட்டம் தேர்ந்தெடுத்து கடையை வரைபடத்தில் குறிக்கவும்.',
              ),
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _advance,
              child: Text(t('Save sample only', 'மாதிரியை மட்டும் சேமி')),
            ),
          ],
        ),
      ),
      4 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sampleHeading(t('Bookings', 'முன்பதிவுகள்')),
          _tile(
            Icons.calendar_month_outlined,
            t('Calendar & history', 'நாட்காட்டி மற்றும் வரலாறு'),
            subtitle: t(
              'Select a date to see its events',
              'தேதியைத் தேர்ந்தெடுத்து நிகழ்வுகளைப் பாருங்கள்',
            ),
          ),
          const SizedBox(height: 16),
          _tile(
            Icons.event_note_outlined,
            t('Open sample booking', 'மாதிரி முன்பதிவைத் திற'),
            key: _target,
            onTap: _practice,
            subtitle: t(
              'Practice Accept / Reject safely',
              'பாதுகாப்பாக ஏற்க / நிராகரிக்க பயிற்சி செய்யுங்கள்',
            ),
          ),
        ],
      ),
      _ => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sampleHeading(t('Me', 'எனது கணக்கு')),
          _tile(Icons.person_outline, t('My Profile', 'எனது சுயவிவரம்')),
          _tile(
            Icons.storefront_outlined,
            t('Business Details', 'வணிக விவரங்கள்'),
          ),
          _tile(
            Icons.tune_outlined,
            t('App Settings', 'செயலி அமைப்புகள்'),
            key: _target,
            onTap: () async {
              await showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(t('App Settings', 'செயலி அமைப்புகள்')),
                  content: Text(
                    t(
                      'Notifications: control booking and account alerts. Phone notification permission must also be enabled.\n\nLanguage: open the language screen and select English or Tamil.\n\nApp Guide is available under Help & Information whenever you want to practice again.',
                      'அறிவிப்புகள்: முன்பதிவு மற்றும் கணக்கு அறிவிப்புகளை நிர்வகிக்கலாம். மொபைல் அறிவிப்பு அனுமதியும் இயக்கப்பட்டிருக்க வேண்டும்.\n\nமொழி: மொழித் திரையில் தமிழ் அல்லது ஆங்கிலம் தேர்வு செய்யலாம்.\n\nமீண்டும் பயிற்சி செய்ய Help & Information பகுதியில் App Guide உள்ளது.',
                    ),
                  ),
                  actions: [
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(t('Got it', 'புரிந்தது')),
                    ),
                  ],
                ),
              );
              if (mounted) _advance();
            },
          ),
        ],
      ),
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: TourOverlay(
        key: ValueKey('preview-$_step'),
        targetKey: _target,
        child: Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.all(18),
          child: content,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(_exit());
    },
    child: Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(t('App Guide', 'செயலி வழிகாட்டி')),
        actions: [
          IconButton(
            onPressed: _closing ? null : _exit,
            tooltip: t(
              _step == 6 ? 'Close' : 'Skip tour',
              _step == 6 ? 'மூடு' : 'பயிற்சியைத் தவிர்',
            ),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const AppContentSkeleton(layout: SkeletonLayout.dashboard)
            : ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Text(
                    t(
                      'PRACTICE MODE • NO REAL CHANGES',
                      'பயிற்சி முறை • உண்மையான மாற்றங்கள் இல்லை',
                    ),
                    style: const TextStyle(
                      color: Color(0xFF80152C),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_localOnly)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        t(
                          'Progress is saved on this device; it will sync when you reconnect.',
                          'முன்னேற்றம் இந்த மொபைலில் சேமிக்கப்படும்; இணையம் வந்ததும் ஒத்திசையும்.',
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  if (_step < 6) ...[
                    TourInstructionCard(
                      step: _step,
                      onBack: _step == 0 || _closing
                          ? null
                          : () => setState(() => _step--),
                    ),
                    const SizedBox(height: 18),
                    // Only one preview exists at a time, so spotlight keys never overlap.
                    _preview(),
                  ] else ...[
                    const SizedBox(height: 30),
                    const Icon(
                      Icons.task_alt,
                      size: 56,
                      color: AppIconColors.standard,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      t('You’re ready to start', 'தொடங்கத் தயாராகிவிட்டீர்கள்'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      t(
                        'Your practice did not create a business, service or booking. Use the dashboard checklist to set up your real account.',
                        'பயிற்சியில் உண்மையான வணிகம், சேவை அல்லது முன்பதிவு உருவாக்கப்படவில்லை. டாஷ்போர்டு பட்டியலில் உங்கள் உண்மையான கணக்கை அமைக்கலாம்.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(height: 1.6),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _closing ? null : _exit,
                      child: Text(
                        t(
                          'Start using Eventor',
                          'Eventor பயன்படுத்தத் தொடங்குங்கள்',
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
      ),
    ),
  );
}
