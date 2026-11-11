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
    final data = _state;
    if (data?.completed == 3) return const SizedBox.shrink();
    if (data == null) {
      if (!_failed) return const SizedBox.shrink();
      return ListTile(
        title: Text(
          AppSettingsScope.translate(
            context,
            "vendor.account_setup_checklist.71a3bbf5",
          ),
        ),
        trailing: TextButton(
          onPressed: _load,
          child: Text(
            AppSettingsScope.translate(context, "vendor.retry.942087cc"),
          ),
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
                AppSettingsScope.translate(
                  context,
                  "vendor.set_up_your_account.34b78ccf",
                ),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppSettingsScope.translate(
                  context,
                  "vendor.value0_of_3_complete.fe71f2fa",
                  args: {"value0": data.completed},
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
                AppSettingsScope.translate(
                  context,
                  "vendor.complete_your_profile.e6c40677",
                ),
                data.profileComplete,
                () => _open(const MyProfileScreen()),
                subtitle: AppSettingsScope.translate(
                  context,
                  "vendor.add_your_name_and_contact_phone.8061a459",
                ),
              ),
              row(
                AppSettingsScope.translate(
                  context,
                  "vendor.add_your_first_business.2d5ed485",
                ),
                data.businessCount > 0,
                () => _open(const AddBusinessScreen()),
              ),
              row(
                AppSettingsScope.translate(
                  context,
                  "vendor.add_your_first_service.88c65d17",
                ),
                data.serviceCount > 0,
                () => _open(
                  data.businessCount == 0
                      ? const AddBusinessScreen()
                      : const ListingEditorScreen(),
                ),
                subtitle: data.businessCount == 0
                    ? AppSettingsScope.translate(
                        context,
                        "vendor.start_by_adding_a_business.acc0a370",
                      )
                    : null,
              ),
              if (_failed)
                TextButton(
                  onPressed: _load,
                  child: Text(
                    AppSettingsScope.translate(
                      context,
                      "vendor.refresh_setup_status.2c8e48ca",
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
