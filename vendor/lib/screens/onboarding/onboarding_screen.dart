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
  String t(String en) => AppSettingsScope.source(context, en);
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
          _error = AppSettingsScope.translate(
            context,
            "vendor.unable_to_save_please_try_again.05cd3aad",
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
                  child: Text(
                    AppSettingsScope.translate(context, "vendor.skip.28d03596"),
                  ),
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
                  title: AppSettingsScope.translate(
                    context,
                    "vendor.welcome_to_eventor.d3155e5c",
                  ),
                  description: AppSettingsScope.translate(
                    context,
                    "vendor.showcase_your_business_and_help_customers_dis.661832e5",
                  ),
                ),
                OnboardingSlide(
                  icon: Icons.photo_library_outlined,
                  title: AppSettingsScope.translate(
                    context,
                    "vendor.your_business_your_services.669273d3",
                  ),
                  description: AppSettingsScope.translate(
                    context,
                    "vendor.add_a_business_choose_its_category_then_list_.932a58b1",
                  ),
                ),
                OnboardingSlide(
                  icon: Icons.calendar_month_outlined,
                  title: AppSettingsScope.translate(
                    context,
                    "vendor.bookings_made_simple.0bca4e6c",
                  ),
                  description: AppSettingsScope.translate(
                    context,
                    "vendor.review_requests_accept_or_reject_bookings_and.ac12978b",
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
              child: Text(AppSettingsScope.source(context, _error!), textAlign: TextAlign.center),
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
                    child: Text(
                      AppSettingsScope.translate(
                        context,
                        "vendor.back.76900f1b",
                      ),
                    ),
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
                        ? AppSettingsScope.translate(
                            context,
                            "vendor.get_started.983f3110",
                          )
                        : AppSettingsScope.translate(
                            context,
                            "vendor.next.1ff57a29",
                          ),
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
