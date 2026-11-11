import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:flutter/material.dart';

import '../repositories/customer_address_repository.dart';
import '../screens/extended/customer_address_screen.dart';
import '../services/app_live_data.dart';

class CustomerAddressCard extends StatefulWidget {
  const CustomerAddressCard({
    super.key,
    this.repository,
    this.margin = const EdgeInsets.fromLTRB(16, 4, 16, 8),
  });
  final CustomerAddressRepository? repository;
  final EdgeInsetsGeometry margin;
  @override
  State<CustomerAddressCard> createState() => _CustomerAddressCardState();
}

class _CustomerAddressCardState extends State<CustomerAddressCard>
    with LiveDataState<CustomerAddressCard> {
  late final repo = widget.repository ?? CustomerAddressRepository();
  String? address;
  bool loading = true, failed = false;
  int generation = 0;
  @override
  Set<String> get liveDatasets => {'own:customers'};
  @override
  Future<void> onLiveData(Set<String> changed) => load();
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final request = ++generation;
    try {
      final value = await repo.load();
      if (mounted && request == generation) {
        setState(() {
          address = value;
          loading = false;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted && request == generation) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  Future<void> edit() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CustomerAddressScreen()),
    );
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) {
    final filled = address?.trim().isNotEmpty == true;
    const wine = Color(0xFF80152C);

    return Container(
      margin: widget.margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0EDF0)),
        boxShadow: [
          BoxShadow(
            color: wine.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF5E8EC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: wine,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppSettingsScope.translate(
                    context,
                    "customer.your_address.abd55b38",
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF17171B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loading
                      ? 'Loading saved address…'
                      : failed
                      ? 'Unable to load your address. Tap Retry.'
                      : filled
                      ? address!
                      : 'No address added. Add your home or contact address.',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF73737D),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: loading
                ? null
                : failed
                ? load
                : edit,
            icon: Icon(
              failed
                  ? Icons.refresh
                  : filled
                  ? Icons.edit_outlined
                  : Icons.add,
              size: 14,
            ),
            label: Text(
              failed
                  ? 'Retry'
                  : filled
                  ? 'Edit'
                  : 'Add',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: wine,
              side: const BorderSide(color: wine),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 32),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
