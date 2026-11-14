import '../../services/app_live_data.dart';

import 'package:flutter/material.dart';

import '../../models/admin_module.dart';
import '../../repositories/admin_repository.dart';
import '../../widgets/admin_management_helpers.dart';

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

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with LiveDataState<AdminDashboardScreen> {
  @override
  Set<String> get liveDatasets => {
    'admin:bookings',
    'admin:users',
    'admin:vendors',
    'admin:customers',
    'admin:services',
    'admin:businesses',
    'admin:service_reviews',
  };

  @override
  Future<void> onLiveData(Set<String> changed) async {
    await refresh();
  }

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

  Widget _metricCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    double? width,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF0EDF0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF80152C).withValues(alpha: 0.03),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: 22),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Color(0xFFA0A0AC),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF17171B),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF73737D),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _queueTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String badgeText,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0EDF0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF80152C).withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF17171B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF73737D),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFA0A0AC),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: loading,
    builder: (context, s) {
      if (s.hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFF80152C),
                size: 44,
              ),
              const SizedBox(height: 14),
              const Text(
                'Unable to load dashboard overview.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        );
      }
      if (!s.hasData) {
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFF80152C)),
        );
      }
      final data = s.data!,
          counts = Map<String, dynamic>.from(data['counts'] as Map);

      final pendingBookings = data['pending_bookings'] ?? 0;
      final openTickets = data['open_tickets'] ?? 0;
      final verificationQueue = data['verification_queue'] ?? 0;
      final openReports = data['open_reports'] ?? 0;
      final deletionQueue = data['deletion_queue'] ?? 0;
      final storageCleanup = counts['admin_storage_cleanup'] as num? ?? 0;

      return RefreshIndicator(
        color: const Color(0xFF80152C),
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.all(24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // Welcome Header & Status
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF0EDF0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF80152C).withValues(alpha: 0.03),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Platform Overview',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF17171B),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'REALTIME SYNC',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Live records, active operational queues, and management across Eventor.',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF73737D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () => widget.onOpen('workspace', {}),
                    icon: const Icon(Icons.grid_view_rounded, size: 18),
                    label: const Text('All Modules'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Key Performance Metrics
            const Text(
              'Key Metrics',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF17171B),
              ),
            ),
            const SizedBox(height: 14),

            LayoutBuilder(
              builder: (c, size) {
                final columns = size.maxWidth >= 1050
                    ? 3
                    : size.maxWidth >= 650
                    ? 2
                    : 1;
                final width = (size.maxWidth - (columns - 1) * 14) / columns;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _metricCard(
                      context: context,
                      title: 'Total Bookings',
                      value: '${counts['bookings'] ?? 0}',
                      icon: Icons.calendar_month_rounded,
                      color: const Color(0xFF80152C),
                      width: width,
                      onTap: () => widget.onOpen('bookings', {}),
                    ),
                    _metricCard(
                      context: context,
                      title: 'Active Services',
                      value: '${counts['services'] ?? 0}',
                      icon: Icons.design_services_rounded,
                      color: const Color(0xFF1565C0),
                      width: width,
                      onTap: () => widget.onOpen('services', {}),
                    ),
                    _metricCard(
                      context: context,
                      title: 'Verified Vendors',
                      value: '${counts['vendors'] ?? 0}',
                      icon: Icons.storefront_rounded,
                      color: const Color(0xFF2E7D32),
                      width: width,
                      onTap: () => widget.onOpen('vendors', {}),
                    ),
                    _metricCard(
                      context: context,
                      title: 'Listed Businesses',
                      value: '${counts['businesses'] ?? 0}',
                      icon: Icons.business_center_rounded,
                      color: const Color(0xFF00897B),
                      width: width,
                      onTap: () => widget.onOpen('businesses', {}),
                    ),
                    _metricCard(
                      context: context,
                      title: 'Customer Accounts',
                      value: '${counts['customers'] ?? 0}',
                      icon: Icons.people_alt_rounded,
                      color: const Color(0xFF6A1B9A),
                      width: width,
                      onTap: () => widget.onOpen('customers', {}),
                    ),
                    _metricCard(
                      context: context,
                      title: 'Service Reviews',
                      value: '${counts['service_reviews'] ?? 0}',
                      icon: Icons.star_rounded,
                      color: const Color(0xFFE65100),
                      width: width,
                      onTap: () => widget.onOpen('service_reviews', {}),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 28),

            // Action Required / Queues Section
            Row(
              children: [
                const Text(
                  'Action Queues',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF17171B),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5E8EC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'PRIORITY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF80152C),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _queueTile(
              context: context,
              title: 'Pending Bookings',
              subtitle:
                  'New booking requests awaiting vendor or customer action',
              badgeText: '$pendingBookings pending',
              icon: Icons.schedule_rounded,
              color: const Color(0xFFE65100),
              onTap: () => widget.onOpen('bookings', {'status': 'pending'}),
            ),

            _queueTile(
              context: context,
              title: 'Open Support Tickets',
              subtitle:
                  'Customer and vendor inquiries awaiting administrative reply',
              badgeText: '$openTickets open',
              icon: Icons.support_agent_rounded,
              color: const Color(0xFF80152C),
              onTap: () => widget.onOpen('support_tickets', {}),
            ),

            _queueTile(
              context: context,
              title: 'Vendor Verification Queue',
              subtitle: 'Vendor business documents submitted for identity verification',
              badgeText: '$verificationQueue queued',
              icon: Icons.verified_user_rounded,
              color: const Color(0xFF1565C0),
              onTap: () => widget.onOpen('vendor_verifications', {}),
            ),

            _queueTile(
              context: context,
              title: 'Review Reports',
              subtitle: 'Customer reviews flagged by community for moderation',
              badgeText: '$openReports reports',
              icon: Icons.flag_rounded,
              color: const Color(0xFF6A1B9A),
              onTap: () =>
                  widget.onOpen('service_review_reports', {'status': 'open'}),
            ),

            _queueTile(
              context: context,
              title: 'Account Deletion Requests',
              subtitle:
                  'Compliance and privacy requests to remove account data',
              badgeText: '$deletionQueue requests',
              icon: Icons.person_remove_rounded,
              color: const Color(0xFFC62828),
              onTap: () => widget.onOpen('account_deletion_requests', {}),
            ),

            if (storageCleanup > 0)
              _queueTile(
                context: context,
                title: 'Storage Cleanup Required',
                subtitle:
                    'Unreferenced files and media ready for permanent cleanup',
                badgeText: '$storageCleanup files',
                icon: Icons.cleaning_services_rounded,
                color: const Color(0xFF00897B),
                onTap: () => widget.onOpen('admin_storage_cleanup', {
                  'status': 'pending',
                }),
              ),

            const SizedBox(height: 28),

            // Recent Platform Activity
            const Text(
              'Recent Platform Activity',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF17171B),
              ),
            ),
            const SizedBox(height: 14),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFF0EDF0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF80152C).withValues(alpha: 0.02),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: (data['recent_audit'] as List? ?? []).isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No recent activity recorded yet.',
                            style: TextStyle(color: Color(0xFF73737D)),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (
                            var i = 0;
                            i < (data['recent_audit'] as List).length;
                            i++
                          ) ...[
                            if (i > 0)
                              const Divider(
                                height: 1,
                                thickness: 1,
                                color: Color(0xFFF5F5F8),
                              ),
                            Builder(
                              builder: (context) {
                                final item = (data['recent_audit'] as List)[i];
                                final action = item['action']?.toString() ?? '';
                                final module = item['module']?.toString() ?? '';
                                final time =
                                    item['created_at']?.toString() ?? '';

                                return Material(
                                  type: MaterialType.transparency,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 6,
                                    ),
                                    leading: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF5E8EC),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.history_rounded,
                                        size: 18,
                                        color: Color(0xFF80152C),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Text(
                                          adminLabel(module),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: Color(0xFF17171B),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF0EDF0),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            adminActionLabel(action)
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF73737D),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      time,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFA0A0AC),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
