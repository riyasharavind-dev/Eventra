import 'package:flutter/material.dart';

import '../../models/admin_module.dart';
import '../../repositories/admin_repository.dart';

class AdminDashboardScreen extends StatefulWidget {
  final AdminRepository repo;
  final List<AdminModule> modules;
  final void Function(String, Map<String, dynamic>) onOpen;
  const AdminDashboardScreen({
    super.key,
    required this.repo,
    required this.modules,
    required this.onOpen,
  });
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<Map<String, dynamic>> loading;
  @override
  void initState() {
    super.initState();
    loading = widget.repo.overview();
  }

  Future<void> refresh() async {
    setState(() {
      loading = widget.repo.overview();
    });
    try {
      await loading;
    } catch (_) {
      /* Render retry. */
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: loading,
    builder: (context, s) {
      if (s.hasError) {
        return Center(
          child: TextButton(
            onPressed: refresh,
            child: const Text('Unable to load overview. Retry'),
          ),
        );
      }
      if (!s.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final data = s.data!,
          counts = Map<String, dynamic>.from(data['counts'] as Map);
      Widget queue(
        String title,
        String count,
        String module,
        Map<String, dynamic> filters,
      ) => Card(
        child: ListTile(
          title: Text(title),
          subtitle: Text(count),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => widget.onOpen(module, filters),
        ),
      );
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.all(24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text(
              'Eventor overview',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Live records and queues across the vendor and customer apps.',
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (c, size) {
                final width = size.maxWidth < 600
                    ? size.maxWidth
                    : (size.maxWidth - 24) / 3;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children:
                      [
                        'vendors',
                        'customers',
                        'businesses',
                        'services',
                        'bookings',
                        'service_reviews',
                      ].map((name) {
                        final module = widget.modules
                            .where((m) => m.name == name)
                            .firstOrNull;
                        return SizedBox(
                          width: width,
                          child: Card(
                            child: InkWell(
                              onTap: () => widget.onOpen(name, {}),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${counts[name] ?? 0}',
                                      style: Theme.of(c)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(module?.label ?? adminLabel(name)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Needs attention',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            queue(
              'Pending bookings',
              '${data['pending_bookings']} requests',
              'bookings',
              {'status': 'pending'},
            ),
            queue(
              'Open support tickets',
              '${data['open_tickets']} tickets',
              'support_tickets',
              {},
            ),
            queue(
              'Vendor verification',
              '${data['verification_queue']} in queue',
              'vendor_verifications',
              {},
            ),
            queue(
              'Review reports',
              '${data['open_reports']} open reports',
              'service_review_reports',
              {'status': 'open'},
            ),
            queue(
              'Account deletion requests',
              '${data['deletion_queue']} in queue',
              'account_deletion_requests',
              {},
            ),
            if ((counts['admin_storage_cleanup'] as num? ?? 0) > 0)
              queue(
                'Storage cleanup',
                'Review pending file cleanup jobs',
                'admin_storage_cleanup',
                {'status': 'pending'},
              ),
            const SizedBox(height: 24),
            Text(
              'Recent admin activity',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final item in data['recent_audit'] as List? ?? [])
              ListTile(
                leading: const Icon(Icons.history),
                title: Text(
                  '${adminLabel(item['module'].toString())} · ${adminLabel(item['action'].toString())}',
                ),
                subtitle: Text(item['created_at'].toString()),
              ),
          ],
        ),
      );
    },
  );
}
