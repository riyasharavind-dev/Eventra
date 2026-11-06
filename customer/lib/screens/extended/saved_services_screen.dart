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

class _SavedServicesScreenState extends State<SavedServicesScreen> {
  late final SavedServicesRepository _repo;
  late Future<List<ServiceModel>> _future;
  String? _opening;
  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? SavedServicesRepository();
    _future = _repo.getSaved();
  }

  Future<void> _load() async {
    final future = _repo.getSaved();
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
          const SnackBar(
            content: Text('Unable to remove saved service. Please retry.'),
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
    appBar: AppBar(title: const Text('Saved Services')),
    body: FutureBuilder<List<ServiceModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: _load,
              child: const Text('Unable to load. Retry'),
            ),
          );
        }
        final rows = snapshot.data ?? [];
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Saved on this device for your account. Tap the heart on a service to save it.',
              ),
              const SizedBox(height: 16),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No saved services yet.'),
                ),
              for (final service in rows)
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: service.gallery.isEmpty
                          ? const SizedBox(
                              width: 56,
                              height: 56,
                              child: Icon(Icons.event_outlined),
                            )
                          : Image.network(
                              service.gallery.first,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, error, stack) =>
                                  const Icon(Icons.image_outlined),
                            ),
                    ),
                    title: Text(service.name),
                    subtitle: Text('₹${service.price.toStringAsFixed(0)}'),
                    trailing: IconButton(
                      tooltip: 'Remove saved service',
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
