import 'package:eventor_customer/services/app_settings_controller.dart';
import '../../core/theme/app_icon_colors.dart';
import '../../screens/extended/business_services_screen.dart';
import 'package:flutter/material.dart';

/// Business aggregates across all its services, separate from service metrics.
class ServiceBusinessCard extends StatelessWidget {
  const ServiceBusinessCard({super.key, required this.data});
  final Map<String, dynamic> data;
  static const wine = Color(0xFF80152C);

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final logo = data['logo_url']?.toString();
    final rating = data['rating'] as num? ?? 0;
    final description = data['description']?.toString().trim();
    Widget fallback() => const ColoredBox(
      color: Color(0xFFF5E8EC),
      child: Center(
        child: Icon(Icons.storefront_outlined, color: wine, size: 28),
      ),
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF0EDF0)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: wine.withValues(alpha: .05),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: logo?.isNotEmpty == true
                      ? Image.network(
                          logo!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => fallback(),
                        )
                      : fallback(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['name']?.toString() ?? 'Business',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF17171B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description?.isNotEmpty == true
                          ? description!
                          : 'Event services',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF73737D),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: AppSettingsScope.translate(
                  context,
                  "customer.view_business_services.62cda499",
                ),
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppIconColors.standard,
                ),
                onPressed: data['id'] == null
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => BusinessServicesScreen(
                            businessId: data['id'].toString(),
                            businessName:
                                data['name']?.toString() ?? 'Business services',
                          ),
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _BusinessMetric(
                  icon: Icons.star_rounded,
                  color: const Color(0xFFFFCB48),
                  value: rating == 0 ? '0' : rating.toStringAsFixed(1),
                  label: AppSettingsScope.translate(
                    context,
                    "customer.value0_reviews.b4881c1c",
                    args: {"value0": data['review_count'] ?? 0},
                  ),
                ),
              ),
              const _BusinessDivider(),
              Expanded(
                child: _BusinessMetric(
                  icon: Icons.event_available_outlined,
                  value: '${data['completed_count'] ?? 0}',
                  label: AppSettingsScope.translate(
                    context,
                    "customer.events_completed.b89b545a",
                  ),
                ),
              ),
              const _BusinessDivider(),
              Expanded(
                child: _BusinessMetric(
                  icon: Icons.storefront_outlined,
                  value: '${data['since_year'] ?? '—'}',
                  label: AppSettingsScope.translate(
                    context,
                    "customer.since.98af1ed6",
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BusinessMetric extends StatelessWidget {
  const _BusinessMetric({
    required this.icon,
    required this.value,
    required this.label,
    this.color = const Color(0xFF80152C),
  });
  final IconData icon;
  final String value, label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 6),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF17171B),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                height: 1.3,
                color: Color(0xFF73737D),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _BusinessDivider extends StatelessWidget {
  const _BusinessDivider();
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 34,
    color: const Color(0xFFF0EDF0),
    margin: const EdgeInsets.symmetric(horizontal: 8),
  );
}
