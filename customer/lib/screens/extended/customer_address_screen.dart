import 'package:eventor_customer/services/app_settings_controller.dart';
import '../../widgets/common/app_empty_state.dart';
import 'package:flutter/material.dart';

import '../../models/customer_address.dart';
import '../../repositories/customer_address_repository.dart';
import '../../services/app_live_data.dart';
import 'customer_address_editor_screen.dart';

class CustomerAddressScreen extends StatefulWidget {
  const CustomerAddressScreen({super.key, this.repository});
  final CustomerAddressRepository? repository;
  @override
  State<CustomerAddressScreen> createState() => _AddressesState();
}

class _AddressesState extends State<CustomerAddressScreen>
    with LiveDataState<CustomerAddressScreen> {
  @override
  Set<String> get liveDatasets => {'own:customers'};
  @override
  Future<void> onLiveData(Set<String> changed) => load();
  late final repo = widget.repository ?? CustomerAddressRepository();
  List<CustomerAddress> rows = [];
  bool loading = true, failed = false, busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await repo.list();
      if (mounted) {
        setState(() {
          rows = data;
          loading = false;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  Future<void> edit([CustomerAddress? address]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerAddressEditorScreen(
          repository: repo,
          address: address,
          firstAddress: rows.isEmpty,
        ),
      ),
    );
    if (saved == true && mounted) await load();
  }

  Future<void> action(CustomerAddress address, {bool remove = false}) async {
    if (busy) return;
    if (remove) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          title: Text(
            AppSettingsScope.translate(
              context,
              "customer.delete_address.65751d33",
            ),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: Color(0xFF17171B),
            ),
          ),
          content: Text(
            address.isActive
                ? 'Another saved address will become active automatically.'
                : 'Remove this saved address?',
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF73737D),
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF73737D),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                AppSettingsScope.translate(context, "customer.cancel.19766ed6"),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                AppSettingsScope.translate(context, "customer.delete.e2d0a549"),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => busy = true);
    try {
      if (remove) {
        await repo.remove(address.id);
      } else {
        await repo.activate(address.id);
      }
      AppLiveData.instance.invalidate({'own:customers'});
      await load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppSettingsScope.translate(
                context,
                "customer.unable_to_update_address_retry.d1f8747f",
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          AppSettingsScope.translate(
            context,
            "customer.your_addresses.f380626d",
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Color(0xFF17171B),
          ),
        ),
        backgroundColor: const Color(0xFFF8F8FA),
        elevation: 0,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: loading || failed || busy || rows.length >= 20
                  ? null
                  : () => edit(),
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                AppSettingsScope.translate(
                  context,
                  "customer.add_address.9ccfb5a8",
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF80152C),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF80152C),
        onRefresh: load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              AppSettingsScope.translate(
                context,
                "customer.save_multiple_addresses_and_choose_one_active.ce44f779",
              ),
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Color(0xFF73737D),
              ),
            ),
            const SizedBox(height: 16),
            if (loading || busy)
              const LinearProgressIndicator(color: Color(0xFF80152C)),
            if (failed)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF80152C),
                    ),
                    onPressed: load,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      AppSettingsScope.translate(
                        context,
                        "customer.unable_to_load_addresses_retry.b90ddabb",
                      ),
                    ),
                  ),
                ),
              ),
            if (!loading && !failed && rows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: AppEmptyState(
                  icon: Icons.location_on_outlined,
                  title: AppSettingsScope.translate(
                    context,
                    "customer.no_addresses_saved_tap_add_address_to_get_sta.33dbf3cc",
                  ),
                  message: 'Add your home or event venue address for fast and easy bookings.',
                ),
              ),
            for (final address in rows)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: address.isActive
                        ? const Color(0xFF80152C)
                        : const Color(0xFFF0EDF0),
                    width: address.isActive ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF80152C).withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5E8EC),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFF80152C),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            address.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Color(0xFF17171B),
                            ),
                          ),
                        ),
                        if (address.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5E8EC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              AppSettingsScope.translate(
                                context,
                                "customer.active.92340695",
                              ),
                              style: const TextStyle(
                                color: Color(0xFF80152C),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      address.fullAddress,
                      style: const TextStyle(
                        height: 1.4,
                        fontSize: 13,
                        color: Color(0xFF17171B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (!address.isActive)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF80152C),
                              textStyle:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            onPressed: busy ? null : () => action(address),
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 16,
                            ),
                            label: Text(
                              AppSettingsScope.translate(
                                context,
                                "customer.use_this_address.25b073bc",
                              ),
                            ),
                          ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF73737D),
                            textStyle:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onPressed: busy ? null : () => edit(address),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: Text(
                            AppSettingsScope.translate(
                              context,
                              "customer.edit.464c4ffd",
                            ),
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFC62828),
                            textStyle:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onPressed: busy
                              ? null
                              : () => action(address, remove: true),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: Text(
                            AppSettingsScope.translate(
                              context,
                              "customer.delete.e2d0a549",
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
