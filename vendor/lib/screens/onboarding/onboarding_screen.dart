import 'package:flutter/material.dart';

import '../../repositories/onboarding_repository.dart';
import '../../services/app_settings_controller.dart';
import '../../widgets/onboarding/onboarding_slide.dart';

class VendorOnboardingGate extends StatefulWidget {
  const VendorOnboardingGate({super.key, required this.child, this.repository});
  final Widget child;
  final OnboardingRepository? repository;
  @override
  State<VendorOnboardingGate> createState() => _VendorOnboardingGateState();
}

class _VendorOnboardingGateState extends State<VendorOnboardingGate> {
  late final repository = widget.repository ?? OnboardingRepository();
  bool? _show;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final show = await repository.needsIntroduction();
      if (mounted) setState(() => _show = show);
    } catch (_) {
      if (mounted) setState(() => _show = false);
    }
  }

  @override
  Widget build(BuildContext context) => _show == null
      ? const Scaffold(body: SizedBox.expand())
      : _show!
      ? OnboardingScreen(
          repository: repository,
          onFinished: () => setState(() => _show = false),
        )
      : widget.child;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onFinished,
    this.repository,
  });
  final VoidCallback onFinished;
  final OnboardingRepository? repository;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _index = 0;
  bool _saving = false;
  String? _error;
  String t(String en, String ta) => AppSettingsScope.of(context).text(en, ta);
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await (widget.repository ?? OnboardingRepository())
          .completeIntroduction();
      if (mounted) widget.onFinished();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = t(
            'Unable to save. Please try again.',
            'சேமிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F8FA),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'EVENTOR',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF80152C),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _saving ? null : _finish,
                  child: Text(t('Skip', 'தவிர்')),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pages,
              onPageChanged: (v) => setState(() => _index = v),
              children: [
                OnboardingSlide(
                  icon: Icons.storefront_outlined,
                  title: t('Welcome to Eventor', 'Eventor வரவேற்கிறது'),
                  description: t(
                    'Showcase your business and help customers discover what you do best.',
                    'உங்கள் வணிகத்தை அறிமுகப்படுத்தி, வாடிக்கையாளர்கள் உங்கள் சேவைகளைக் கண்டறிய உதவுங்கள்.',
                  ),
                ),
                OnboardingSlide(
                  icon: Icons.photo_library_outlined,
                  title: t(
                    'Your business. Your services.',
                    'உங்கள் வணிகம். உங்கள் சேவைகள்.',
                  ),
                  description: t(
                    'Add a business, choose its category, then list services with photos and your preferred pricing.',
                    'வணிகம் மற்றும் அதன் வகையைச் சேர்த்து, படங்கள் மற்றும் விருப்பமான விலையுடன் சேவைகளைப் பட்டியலிடுங்கள்.',
                  ),
                ),
                OnboardingSlide(
                  icon: Icons.calendar_month_outlined,
                  title: t('Bookings, made simple', 'எளிமையான முன்பதிவுகள்'),
                  description: t(
                    'Review requests, accept or reject bookings, and track events and history in your calendar.',
                    'கோரிக்கைகளைப் பார்த்து ஏற்கலாம் அல்லது நிராகரிக்கலாம். நாட்காட்டியில் நிகழ்வுகளையும் வரலாற்றையும் பார்க்கலாம்.',
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: i == _index ? 25 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: i == _index
                      ? const Color(0xFF80152C)
                      : const Color(0xFFDEDEE4),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, textAlign: TextAlign.center),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: 12,
              overflowSpacing: 8,
              children: [
                if (_index > 0)
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => _pages.previousPage(
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.easeOutCubic,
                          ),
                    child: Text(t('Back', 'முன்பு')),
                  ),
                FilledButton(
                  onPressed: _saving
                      ? null
                      : _index == 2
                      ? _finish
                      : () => _pages.nextPage(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                        ),
                  child: Text(
                    _index == 2
                        ? t('Get Started', 'தொடங்குங்கள்')
                        : t('Next', 'அடுத்து'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
