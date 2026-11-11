import 'package:eventor_customer/services/app_settings_controller.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../services/app_live_data.dart';

import 'package:flutter/material.dart';

import '../../models/service_model.dart';
import '../../repositories/saved_services_repository.dart';
import '../../repositories/service_repository.dart';
import 'service_details_screen.dart';

class SavedServicesScreen extends StatefulWidget {
  const SavedServicesScreen({super.key, this.repository});
  final SavedServicesRepository? repository;
  @override
  State<SavedServicesScreen> createState() => _SavedServicesScreenState();
}

class _SavedServicesScreenState extends State<SavedServicesScreen>
    with LiveDataState<SavedServicesScreen> {
  @override
  Set<String> get liveDatasets => {
    'public:services',
    'own:customer_service_collections',
    'public:businesses',
    'public:vendors',
    'local_saved_services',
  };
  @override
  Future<void> onLiveData(Set<String> changed) async {
    await _repo.getSaved(refresh: true);
    await _load();
  }

  late final SavedServicesRepository _repo;
  late Future<List<ServiceModel>> _future;
  String? _opening;
  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? SavedServicesRepository();
    _future = _readSaved();
  }

  Future<List<ServiceModel>> _readSaved() async {
    final saved = await _repo.getSaved();
    try {
      final fresh = await ServiceRepository().getServicesByIds(
        saved.map((s) => s.id).toList(),
      );
      final byId = {for (final s in fresh) s.id: s};
      return saved
          .map(
            (s) =>
                byId[s.id] ??
                ServiceModel.fromMap({...s.toMap(), 'is_active': false}),
          )
          .toList();
    } catch (_) {
      return saved;
    }
  }

  Future<void> _load() async {
    final future = _readSaved();
    setState(() {
      _future = future;
    });
    try {
      await future;
    } catch (_) {}
  }

  Future<void> _remove(ServiceModel service) async {
    try {
      await _repo.setSaved(service, false);
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppSettingsScope.translate(
                context,
                "customer.unable_to_remove_saved_service_please_retry.443bc419",
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _open(ServiceModel saved) async {
    if (_opening != null) return;
    setState(() => _opening = saved.id);
    try {
      final service = await ServiceRepository().getServiceById(saved.id);
      if (!mounted) return;
      if (service == null || !service.isActive) {
        throw StateError('This service is no longer available.');
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ServiceDetailsScreen(service: service),
        ),
      );
      if (mounted) await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError
                  ? error.message.toString()
                  : 'Unable to open the service. Please retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F8FA),
    appBar: AppBar(
      centerTitle: true,
      title: Text(
        AppSettingsScope.translate(context, "customer.saved_services.433e4634"),
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: Color(0xFF17171B),
        ),
      ),
      backgroundColor: const Color(0xFFF8F8FA),
      elevation: 0,
    ),
    body: FutureBuilder<List<ServiceModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF80152C)),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF80152C),
              ),
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: Text(
                AppSettingsScope.translate(
                  context,
                  "customer.unable_to_load_retry.007ee6bc",
                ),
              ),
            ),
          );
        }
        final rows = snapshot.data ?? [];
        return RefreshIndicator(
          color: const Color(0xFF80152C),
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                AppSettingsScope.translate(
                  context,
                  "customer.saved_on_this_device_for_your_account_tap_the.30fe77e0",
                ),
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF73737D),
                ),
              ),
              const SizedBox(height: 16),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: AppEmptyState(
                    icon: Icons.favorite_border_rounded,
                    title: AppSettingsScope.translate(
                      context,
                      "customer.no_saved_services_yet.d842f6a0",
                    ),
                    message: 'Tap the heart icon on any service to save it here for quick access.',
                  ),
                ),
              for (final service in rows)
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
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: service.gallery.isEmpty
                          ? Container(
                              width: 60,
                              height: 60,
                              color: const Color(0xFFF5E8EC),
                              child: const Icon(
                                Icons.event_outlined,
                                color: Color(0xFF80152C),
                              ),
                            )
                          : Image.network(
                              service.gallery.first,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (_, error, stack) => Container(
                                width: 60,
                                height: 60,
                                color: const Color(0xFFF5E8EC),
                                child: const Icon(
                                  Icons.image_outlined,
                                  color: Color(0xFF80152C),
                                ),
                              ),
                            ),
                    ),
                    title: Text(
                      service.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF17171B),
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '₹${service.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF80152C),
                        ),
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: AppSettingsScope.translate(
                        context,
                        "customer.remove_saved_service.37d31798",
                      ),
                      icon: const Icon(
                        Icons.favorite,
                        color: Color(0xFF80152C),
                      ),
                      onPressed: () => _remove(service),
                    ),
                    onTap: () => _open(service),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
