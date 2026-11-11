import 'package:eventor_customer/services/app_settings_controller.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/service_cart_repository.dart';
import '../../services/app_live_data.dart';

/// Account-scoped count updates only after Added Services changes are saved.
class AddedServicesIcon extends StatefulWidget {
  const AddedServicesIcon({
    super.key,
    this.size = 24,
    this.color = const Color(0xFF73737D),
  });
  final double size;
  final Color color;
  @override
  State<AddedServicesIcon> createState() => _AddedServicesIconState();
}

class _AddedServicesIconState extends State<AddedServicesIcon>
    with LiveDataState<AddedServicesIcon> {
  @override
  Set<String> get liveDatasets => {'own:customer_service_collections'};
  @override
  bool get liveAlwaysActive => true;
  @override
  Future<void> onLiveData(Set<String> changed) async {
    if (uid != null) await ServiceCartRepository().load(refresh: true);
  }

  StreamSubscription<AuthState>? auth;
  String? uid;
  @override
  void initState() {
    super.initState();
    try {
      uid = Supabase.instance.client.auth.currentUser?.id;
      auth = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
        if (!mounted) return;
        setState(() => uid = state.session?.user.id);
        refresh();
      });
      refresh();
    } catch (_) {
      /* Render a plain icon when no signed-in account exists. */
    }
  }

  Future<void> refresh() async {
    if (uid == null) return;
    try {
      await ServiceCartRepository().load();
    } catch (_) {}
  }

  @override
  void dispose() {
    auth?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<Map<String, int>>(
        valueListenable: ServiceCartRepository.counts,
        builder: (context, counts, _) {
          final count = uid == null ? 0 : counts[uid] ?? 0;
          return Semantics(
            label: AppSettingsScope.translate(
              context,
              "customer.added_services_value0_items.0e872400",
              args: {"value0": count},
            ),
            child: Badge.count(
              count: count,
              isLabelVisible: count > 0,
              backgroundColor: const Color(0xFF80152C),
              textColor: Colors.white,
              child: Icon(
                Icons.checklist_rounded,
                color: widget.color,
                size: widget.size,
              ),
            ),
          );
        },
      );
}
