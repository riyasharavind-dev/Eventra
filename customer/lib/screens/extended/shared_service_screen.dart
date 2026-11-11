import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:flutter/material.dart';

import '../../models/service_model.dart';
import '../../repositories/service_repository.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_error_state.dart';
import 'service_details_screen.dart';

class SharedServiceScreen extends StatefulWidget {
  const SharedServiceScreen({super.key, required this.serviceId});
  final String serviceId;
  @override
  State<SharedServiceScreen> createState() => _SharedServiceState();
}

class _SharedServiceState extends State<SharedServiceScreen> {
  late Future<ServiceModel?> service;
  @override
  void initState() {
    super.initState();
    service = ServiceRepository().getServiceById(widget.serviceId);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ServiceModel?>(
    future: service,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(
          backgroundColor: Color(0xFFF8F8FA),
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFF80152C)),
          ),
        );
      }
      if (snapshot.hasError) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F8FA),
          appBar: AppBar(
            title: Text(
              AppSettingsScope.translate(context, "customer.service.d677190e"),
            ),
          ),
          body: Center(
            child: AppErrorState(
              title: AppSettingsScope.translate(
                context,
                "customer.unable_to_load_service_retry.22d8a612",
              ),
              onRetry: () => setState(
                () => service = ServiceRepository().getServiceById(
                  widget.serviceId,
                ),
              ),
            ),
          ),
        );
      }
      final item = snapshot.data;
      if (item == null || !item.isActive) {
        return Scaffold(
          backgroundColor: const Color(0xFFF8F8FA),
          appBar: AppBar(
            title: Text(
              AppSettingsScope.translate(context, "customer.service.d677190e"),
            ),
          ),
          body: Center(
            child: AppEmptyState(
              icon: Icons.inventory_2_outlined,
              title: AppSettingsScope.translate(
                context,
                "customer.this_service_is_no_longer_available.bf16bb61",
              ),
            ),
          ),
        );
      }
      return ServiceDetailsScreen(service: item);
    },
  );
}
