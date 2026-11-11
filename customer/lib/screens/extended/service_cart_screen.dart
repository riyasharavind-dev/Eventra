import 'package:eventor_customer/services/app_settings_controller.dart';
import '../../core/theme/app_icon_colors.dart';
import '../../widgets/common/app_empty_state.dart';
import 'package:flutter/material.dart';

import '../../models/service_model.dart';
import '../../repositories/service_cart_repository.dart';
import '../../repositories/service_repository.dart';
import '../../repositories/recommendation_repository.dart';
import '../../services/app_live_data.dart';
import 'booking_screen.dart';

class ServiceCartScreen extends StatefulWidget {
  const ServiceCartScreen({super.key});
  @override
  State<ServiceCartScreen> createState() => _ServiceCartScreenState();
}

class _ServiceCartScreenState extends State<ServiceCartScreen>
    with LiveDataState<ServiceCartScreen> {
  final cart = ServiceCartRepository();
  List<String> ids = [];
  Map<String, ServiceModel> services = {};
  Set<String> selected = {};
  bool loading = true, failed = false, checkingOut = false;
  int generation = 0;
  @override
  Set<String> get liveDatasets => {
    'public:services',
    'own:customer_service_collections',
    'public:businesses',
    'public:vendors',
  };
  @override
  Future<void> onLiveData(Set<String> changed) async {
    await cart.load(refresh: true);
    await load();
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final request = ++generation;
    try {
      final saved = await cart.load();
      final rows = await ServiceRepository().getServicesByIds(saved);
      if (!mounted || request != generation) return;
      setState(() {
        ids = saved;
        services = {for (final s in rows) s.id: s};
        selected = rows.where((s) => s.isActive).map((s) => s.id).toSet();
        loading = false;
        failed = false;
      });
    } catch (_) {
      if (mounted && request == generation) {
        setState(() {
          failed = true;
          loading = false;
        });
      }
    }
  }

  Future<void> remove(String id) async {
    try {
      await cart.removeAll([id]);
      if (mounted) {
        setState(() {
          ids.remove(id);
          selected.remove(id);
        });
      }
    } catch (_) {
      message('Unable to remove service. Retry.');
    }
  }

  void message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
    }
  }

  Future<void> checkout() async {
    if (checkingOut || selected.isEmpty) return;
    setState(() => checkingOut = true);
    final chosen = [
      for (final id in ids)
        if (selected.contains(id) && services[id]?.isActive == true)
          services[id]!,
    ];
    try {
      final booked = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              BookingScreen(service: chosen.first, services: chosen),
        ),
      );
      if (booked == true) {
        try {
          await cart.removeAll(chosen.map((s) => s.id));
        } catch (_) {
          message(
            'Bookings sent. Unable to clear added services; remove booked items before booking again.',
          );
        }
        RecommendationRepository.changes.value++;
        AppLiveData.instance.invalidate({'own:bookings'});
      }
      if (mounted) await load();
    } finally {
      if (mounted) setState(() => checkingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F8FA),
    appBar: AppBar(
      centerTitle: true,
      title: Text(
        AppSettingsScope.translate(
          context,
          "customer.added_services_value0.bb977bf4",
          args: {"value0": ids.length},
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
    bottomNavigationBar: ids.isEmpty
        ? null
        : SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: loading || failed || selected.isEmpty || checkingOut
                      ? null
                      : checkout,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF80152C),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(
                    AppSettingsScope.translate(
                      context,
                      "customer.book_selected_value0.3283cf89",
                      args: {"value0": selected.length},
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
          if (loading) const LinearProgressIndicator(color: Color(0xFF80152C)),
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
                      "customer.unable_to_load_added_services_retry.514543ac",
                    ),
                  ),
                ),
              ),
            ),
          if (!loading && !failed && ids.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: AppEmptyState(
                icon: Icons.checklist_rounded,
                title: AppSettingsScope.translate(
                  context,
                  "customer.no_services_added_yet_tap_add_service_to_buil.91d3a659",
                ),
                message: 'Explore services and add them to your cart to book together.',
              ),
            ),
          for (final id in ids)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFF0EDF0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF80152C).withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                leading: Checkbox(
                  activeColor: const Color(0xFF80152C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  value: selected.contains(id),
                  onChanged: services[id]?.isActive == true && !checkingOut
                      ? (value) => setState(() {
                          value == true
                              ? selected.add(id)
                              : selected.remove(id);
                        })
                      : null,
                ),
                title: Text(
                  services[id]?.name ?? 'Unavailable service',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF17171B),
                  ),
                ),
                subtitle: Text(
                  services[id]?.isActive == true
                      ? services[id]!.priceLabel
                      : 'This service is no longer available',
                  style: TextStyle(
                    fontSize: 12,
                    color: services[id]?.isActive == true
                        ? const Color(0xFF80152C)
                        : const Color(0xFF73737D),
                    fontWeight: services[id]?.isActive == true
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
                trailing: IconButton(
                  tooltip: AppSettingsScope.translate(
                    context,
                    "customer.remove_service.d9cf844d",
                  ),
                  onPressed: checkingOut ? null : () => remove(id),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppIconColors.standard,
                    size: 20,
                  ),
                ),
              ),
            ),
          if (ids.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                AppSettingsScope.translate(
                  context,
                  "customer.select_the_services_you_want_and_book_them_to.f05b4e55",
                ),
                style: const TextStyle(fontSize: 12, color: Color(0xFF73737D)),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    ),
  );
}
