import 'package:flutter/material.dart';

import '../../models/vendor_tour_step.dart';
import '../../repositories/onboarding_repository.dart';
import '../../screens/extended/my_profile.dart';
import '../../screens/extended/business_details.dart';
import '../../screens/extended/listing_editor_screen.dart';
import '../../services/app_live_data.dart';
import '../../services/app_settings_controller.dart';
import '../../core/theme/app_icon_colors.dart';

class VendorSetupChecklistCard extends StatefulWidget {
  const VendorSetupChecklistCard({super.key, this.repository});
  final OnboardingRepository? repository;
  @override
  State<VendorSetupChecklistCard> createState() =>
      _VendorSetupChecklistCardState();
}

class _VendorSetupChecklistCardState extends State<VendorSetupChecklistCard>
    with LiveDataState<VendorSetupChecklistCard> {
  late final _repository = widget.repository ?? OnboardingRepository();
  VendorSetupChecklist? _state;
  bool _failed = false, _opening = false;
  int _generation = 0;
  @override
  Set<String> get liveDatasets => {
    'own:vendors',
    'own:businesses',
    'own:services',
  };
  @override
  Future<void> onLiveData(Set<String> changed) => _load();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final state = await _repository.loadChecklist();
      if (mounted && generation == _generation) {
        setState(() {
          _state = state;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    }
  }

  Future<void> _open(Widget screen) async {
    if (_opening) return;
    setState(() => _opening = true);
    await Navigator.of(context)
        .push(MaterialPageRoute<Object?>(builder: (_) => screen));
    if (!mounted) return;
    setState(() => _opening = false);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    String t(String en, String ta) => settings.text(en, ta);
    final data = _state;
    if (data?.completed == 3) return const SizedBox.shrink();
    if (data == null) {
      if (!_failed) return const SizedBox.shrink();
      return ListTile(
        title: Text(t('Account setup checklist', 'கணக்கு அமைப்பு பட்டியல்')),
        trailing: TextButton(
          onPressed: _load,
          child: Text(t('Retry', 'மீண்டும்')),
        ),
      );
    }
    Widget row(
      String title,
      bool done,
      VoidCallback onTap, {
      String? subtitle,
    }) => ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        done ? Icons.check_circle_outline : Icons.radio_button_unchecked,
        color: AppIconColors.standard,
      ),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: done ? null : const Icon(Icons.chevron_right),
      onTap: done || _opening ? null : onTap,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t('Set up your account', 'உங்கள் கணக்கை அமைக்கவும்'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                t(
                  '${data.completed} of 3 complete',
                  '${data.completed} / 3 முடிந்தது',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppIconColors.standard,
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: data.completed / 3,
                color: const Color(0xFF80152C),
                backgroundColor: const Color(0xFFECECF0),
                minHeight: 3,
              ),
              row(
                t('Complete your profile', 'சுயவிவரத்தை முடிக்கவும்'),
                data.profileComplete,
                () => _open(const MyProfileScreen()),
                subtitle: t(
                  'Add your name and contact phone',
                  'பெயர் மற்றும் தொடர்பு எண்ணைச் சேர்க்கவும்',
                ),
              ),
              row(
                t('Add your first business', 'முதல் வணிகத்தைச் சேர்க்கவும்'),
                data.businessCount > 0,
                () => _open(const AddBusinessScreen()),
              ),
              row(
                t('Add your first service', 'முதல் சேவையைச் சேர்க்கவும்'),
                data.serviceCount > 0,
                () => _open(
                  data.businessCount == 0
                      ? const AddBusinessScreen()
                      : const ListingEditorScreen(),
                ),
                subtitle: data.businessCount == 0
                    ? t(
                        'Start by adding a business',
                        'முதலில் ஒரு வணிகத்தைச் சேர்க்கவும்',
                      )
                    : null,
              ),
              if (_failed)
                TextButton(
                  onPressed: _load,
                  child: Text(
                    t('Refresh setup status', 'நிலையைப் புதுப்பிக்கவும்'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
