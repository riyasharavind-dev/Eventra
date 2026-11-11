import 'package:eventor_customer/services/app_settings_controller.dart';

import 'service_price_summary.dart';

import 'package:flutter/material.dart';

import '../../models/service_model.dart';

class ServiceInfoSection extends StatelessWidget {
  const ServiceInfoSection({
    super.key,
    required this.service,
    this.overview = const {},
  });
  final ServiceModel service;
  final Map<String, dynamic> overview;
  @override
  Widget build(BuildContext context) {
    final business = overview['business_name']?.toString().trim();
    final location = overview['subdistrict']?.toString().trim();
    final rating = overview['rating'] as num?;
    final count = overview['review_count'] as num? ?? 0;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(
                        fontSize: 23,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF17171B),
                      ),
                    ),
                    const SizedBox(height: 7),
                    if (business?.isNotEmpty == true)
                      Text(
                        AppSettingsScope.translate(
                          context,
                          "customer.by_value0.f3856cb1",
                          args: {"value0": business},
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF73737D),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF17171B),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFCB48),
                      size: 22,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      rating == null || rating == 0
                          ? '0'
                          : rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      ' ($count)',
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ServicePriceSummary(service: service, overview: overview),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: _ServiceFact(
                  icon: Icons.location_on_outlined,
                  label: location?.isNotEmpty == true
                      ? location!
                      : 'Not specified',
                ),
              ),
              const _FactDivider(),
              Expanded(
                flex: 3,
                child: _ServiceFact(
                  icon: Icons.event_available_outlined,
                  label: AppSettingsScope.translate(
                    context,
                    "customer.value0_bookings.ca192175",
                    args: {"value0": overview['booking_count'] ?? 0},
                  ),
                  tooltip: AppSettingsScope.translate(
                    context,
                    "customer.value0_service_bookings.639aa3ba",
                    args: {"value0": overview['booking_count'] ?? 0},
                  ),
                ),
              ),
              const _FactDivider(),
              Expanded(
                flex: 3,
                child: _ServiceFact(
                  icon: Icons.currency_rupee_rounded,
                  label: service.pricing.type.label,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceFact extends StatelessWidget {
  const _ServiceFact({required this.icon, required this.label, this.tooltip});
  final IconData icon;
  final String label;
  final String? tooltip;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip ?? label,
    child: Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF73737D)),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFF17171B), fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _FactDivider extends StatelessWidget {
  const _FactDivider();
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 18,
    margin: const EdgeInsets.symmetric(horizontal: 9),
    color: const Color(0xFFF0EDF0),
  );
}
