import 'package:eventor_customer/services/app_settings_controller.dart';
import '../../core/theme/app_icon_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/customer_address.dart';
import '../../repositories/customer_address_repository.dart';
import '../../widgets/address/region_selector.dart';
import '../../services/app_live_data.dart';

class CustomerAddressEditorScreen extends StatefulWidget {
  const CustomerAddressEditorScreen({
    super.key,
    required this.repository,
    this.address,
    this.firstAddress = false,
  });
  final CustomerAddressRepository repository;
  final CustomerAddress? address;
  final bool firstAddress;
  @override
  State<CustomerAddressEditorScreen> createState() => _AddressEditorState();
}

class _AddressEditorState extends State<CustomerAddressEditorScreen> {
  final form = GlobalKey<FormState>();
  final street = TextEditingController(),
      area = TextEditingController(),
      pin = TextEditingController();
  AddressRegion? state, district, subdistrict;
  String label = 'Home';
  bool makeActive = false, saving = false, picking = false;
  @override
  void initState() {
    super.initState();
    final a = widget.address;
    if (a != null) {
      street.text = a.addressLine;
      area.text = a.area;
      pin.text = a.pin;
      state = a.state;
      district = a.district;
      subdistrict = a.subdistrict;
      label = ['Home', 'Work', 'Other'].contains(a.label) ? a.label : 'Other';
    }
    makeActive = widget.firstAddress || (a?.isActive ?? false);
  }

  @override
  void dispose() {
    street.dispose();
    area.dispose();
    pin.dispose();
    super.dispose();
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> pick(String level) async {
    if (picking || saving) return;
    final parent = level == 'district'
        ? state?.id
        : level == 'subdistrict'
        ? district?.id
        : null;
    if (level != 'state' && parent == null) return;
    setState(() => picking = true);
    try {
      final rows = await widget.repository.regions(level, parentId: parent);
      if (!mounted) return;
      if (rows.isEmpty) {
        message(
          'No locations available here yet. Sub-district can be left empty.',
        );
        return;
      }
      setState(() => picking = false);
      final selected = await selectAddressRegion(
        context,
        title: level == 'state'
            ? 'Select State'
            : level == 'district'
            ? 'Select District'
            : 'Select Sub-district',
        regions: rows,
        selectedId: level == 'state'
            ? state?.id
            : level == 'district'
            ? district?.id
            : subdistrict?.id,
      );
      if (selected == null || !mounted) return;
      setState(() {
        if (level == 'state') {
          state = selected;
          district = null;
          subdistrict = null;
        } else if (level == 'district') {
          district = selected;
          subdistrict = null;
        } else {
          subdistrict = selected;
        }
      });
    } catch (_) {
      message('Unable to load locations. Please retry.');
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    if (state == null || district == null) {
      message('Select your state and district.');
      return;
    }
    setState(() => saving = true);
    try {
      await widget.repository.saveAddress(
        id: widget.address?.id,
        label: label,
        street: street.text,
        area: area.text,
        pin: pin.text,
        state: state!,
        district: district!,
        subdistrict: subdistrict,
        makeActive: makeActive,
      );
      AppLiveData.instance.invalidate({'own:customers'});
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      message('Unable to save. Check your address selections and try again.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget region(
    String title,
    String? name,
    VoidCallback action, {
    bool enabled = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: InkWell(
      onTap: !saving && !picking && enabled ? action : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : const Color(0xFFFAF9FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF0EDF0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF73737D),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name ?? 'Select ${title.replaceAll(' (optional)', '')}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: name == null
                          ? const Color(0xFF73737D)
                          : const Color(0xFF17171B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppIconColors.standard,
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          widget.address == null ? 'Add Address' : 'Edit Address',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Color(0xFF17171B),
          ),
        ),
        backgroundColor: const Color(0xFFF8F8FA),
        elevation: 0,
      ),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              AppSettingsScope.translate(
                context,
                "customer.choose_your_area_then_add_local_details.8465b4e4",
              ),
              style: const TextStyle(fontSize: 13, color: Color(0xFF73737D)),
            ),
            const SizedBox(height: 18),
            if (picking)
              const LinearProgressIndicator(color: Color(0xFF80152C)),
            region('State', state?.name, () => pick('state')),
            region(
              'District',
              district?.name,
              () => pick('district'),
              enabled: state != null,
            ),
            region(
              'Sub-district (optional)',
              subdistrict?.name,
              () => pick('subdistrict'),
              enabled: district != null,
            ),
            TextFormField(
              controller: street,
              enabled: !saving,
              maxLength: 1000,
              minLines: 2,
              maxLines: 3,
              autofillHints: const [AutofillHints.streetAddressLine1],
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: AppSettingsScope.translate(
                  context,
                  "customer.house_flat_building_and_street.f746e3c5",
                ),
                alignLabelWithHint: true,
              ),
              validator: (v) => (v?.trim().length ?? 0) >= 3
                  ? null
                  : AppSettingsScope.translate(
                      context,
                      "customer.enter_house_street_details.916b7075",
                    ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: area,
              enabled: !saving,
              maxLength: 200,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: AppSettingsScope.translate(
                  context,
                  "customer.local_area_locality.6008481c",
                ),
              ),
              validator: (v) => (v?.trim().length ?? 0) >= 2
                  ? null
                  : AppSettingsScope.translate(
                      context,
                      "customer.enter_your_local_area.eb0e9414",
                    ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: pin,
              enabled: !saving,
              maxLength: 6,
              autofillHints: const [AutofillHints.postalCode],
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: AppSettingsScope.translate(
                  context,
                  "customer.pin_code.63701dfd",
                ),
              ),
              validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '')
                  ? null
                  : AppSettingsScope.translate(
                      context,
                      "customer.enter_a_six_digit_pin_code.700c3fc7",
                    ),
            ),
            const SizedBox(height: 14),
            Text(
              AppSettingsScope.translate(context, "customer.save_as.60af8a30"),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: Color(0xFF17171B),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final value in ['Home', 'Work', 'Other'])
                  ChoiceChip(
                    label: Text(value),
                    selected: label == value,
                    selectedColor: const Color(0xFFF5E8EC),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: label == value
                            ? const Color(0xFF80152C)
                            : const Color(0xFFF0EDF0),
                      ),
                    ),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: label == value
                          ? const Color(0xFF80152C)
                          : const Color(0xFF73737D),
                    ),
                    onSelected: saving
                        ? null
                        : (_) => setState(() => label = value),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: const Color(0xFF80152C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              title: Text(
                AppSettingsScope.translate(
                  context,
                  "customer.use_as_active_address.c59e27c3",
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF17171B),
                ),
              ),
              subtitle: Text(
                AppSettingsScope.translate(
                  context,
                  "customer.this_address_will_appear_on_service_details_a.547befd7",
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF73737D),
                ),
              ),
              value: makeActive,
              onChanged:
                  saving ||
                      widget.firstAddress ||
                      (widget.address?.isActive ?? false)
                  ? null
                  : (v) => setState(() => makeActive = v ?? false),
            ),
            Text(
              AppSettingsScope.translate(
                context,
                "customer.this_is_your_contact_address_event_venue_is_e.2d914384",
              ),
              style: const TextStyle(fontSize: 12, color: Color(0xFF73737D)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: saving || picking ? null : save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF80152C),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                child: Text(saving ? 'Saving…' : 'Save Address'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
