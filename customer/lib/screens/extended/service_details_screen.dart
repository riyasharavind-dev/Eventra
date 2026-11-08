import '../../services/app_live_data.dart';
import '../../repositories/service_repository.dart';

import 'dart:async';

import '../../repositories/recommendation_repository.dart';
import '../../widgets/recommendations/service_recommendations_section.dart';

import 'package:flutter/material.dart';

import '../../models/service_model.dart';
import '../../repositories/saved_services_repository.dart';

import '../../widgets/service_details/service_action_bar.dart';
import '../../widgets/service_details/service_description_section.dart';
import '../../widgets/service_details/service_details_section.dart';
import '../../widgets/service_details/service_gallery.dart';
import '../../widgets/service_details/service_info_section.dart';

import 'booking_screen.dart';

class ServiceDetailsScreen extends StatefulWidget {
  final ServiceModel service;

  const ServiceDetailsScreen({super.key, required this.service});

  @override
  State<ServiceDetailsScreen> createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends State<ServiceDetailsScreen>
    with LiveDataState<ServiceDetailsScreen> {
  late ServiceModel _service;
  bool _available = true;
  @override
  Set<String> get liveDatasets => {
    'public:services',
    'public:businesses',
    'public:vendors',
    'public:service_reviews',
    'public:service_metrics',
  };
  @override
  Future<void> onLiveData(Set<String> changed) async {
    if (changed.any(
      (d) =>
          d == 'public:services' ||
          d == 'public:businesses' ||
          d == 'public:vendors',
    )) {
      final fresh = await ServiceRepository().getServiceById(_service.id);
      if (!mounted) return;
      setState(() {
        _available = fresh != null && fresh.isActive;
        if (fresh != null) _service = fresh;
      });
    }
    await _recommendations.refresh();
  }

  late final RecommendationController _recommendations;
  bool _isFavorite = false;
  bool _savingFavorite = true;
  late final SavedServicesRepository _saved;
  @override
  void initState() {
    super.initState();
    _service = widget.service;
    _saved = SavedServicesRepository();
    final recommendations = RecommendationRepository();
    _recommendations = RecommendationController(
      repository: recommendations,
      serviceId: widget.service.id,
    );
    // Load related items immediately; recording interest is independent of this query.
    unawaited(_recommendations.refresh());
    unawaited(recommendations.signal(widget.service.id, 'view'));
    _loadFavorite();
  }

  @override
  void dispose() {
    _recommendations.dispose();
    super.dispose();
  }

  Future<void> _loadFavorite() async {
    try {
      final saved = await _saved.contains(widget.service.id);
      if (mounted) setState(() => _isFavorite = saved);
    } catch (_) {
      // Keep the heart available so a later save can be retried.
    } finally {
      if (mounted) setState(() => _savingFavorite = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_savingFavorite) return;
    setState(() => _savingFavorite = true);
    try {
      final next = !_isFavorite;
      await _saved.setSaved(_service, next);
      if (mounted) setState(() => _isFavorite = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save service. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingFavorite = false);
    }
  }

  // ============================================================
  // ADD TO PLAN
  // ============================================================

  void _addToPlan() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add to Plan will be available soon.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // BOOK SERVICE
  // ============================================================

  Future<void> _bookService() async {
    if (!_available) return;
    final bool? bookingCreated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => BookingScreen(service: _service)),
    );

    if (!mounted) {
      return;
    }

    if (bookingCreated == true) {
      RecommendationRepository.changes.value++;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking request created successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final ServiceModel service = _service;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      // ========================================================
      // FIXED BOTTOM ACTION BAR
      // ========================================================
      bottomNavigationBar: !_available
          ? null
          : ServiceActionBar(
              onAddToPlan: _addToPlan,
              onBookService: _bookService,
            ),

      // ========================================================
      // SCREEN CONTENT
      // ========================================================
      body: !_available
          ? const Center(child: Text('This service is no longer available.'))
          : CustomScrollView(
              slivers: [
                // ======================================================
                // APP BAR
                // ======================================================

                SliverAppBar(
                  pinned: true,
                  elevation: 0,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,

                  title: const Text(
                    'Service Details',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),

                  actions: [
                    IconButton(
                      tooltip: 'Favorite',

                      onPressed: _savingFavorite ? null : _toggleFavorite,

                      icon: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,

                        color: _isFavorite ? Colors.red : Colors.black,
                      ),
                    ),

                    const SizedBox(width: 4),
                  ],
                ),

                // ======================================================
                // GALLERY
                // ======================================================
                SliverToBoxAdapter(
                  child: ServiceGallery(gallery: service.gallery),
                ),

                // ======================================================
                // SERVICE INFO
                // ======================================================
                SliverToBoxAdapter(child: ServiceInfoSection(service: service)),

                // ======================================================
                // DESCRIPTION
                // ======================================================
                SliverToBoxAdapter(
                  child: ServiceDescriptionSection(service: service),
                ),

                // ======================================================
                // SERVICE DETAILS
                // ======================================================
                SliverToBoxAdapter(
                  child: ServiceDetailsSection(service: service),
                ),

                // ======================================================
                // BOTTOM SPACE
                // ======================================================
                SliverToBoxAdapter(
                  child: ServiceRecommendationsSection(
                    controller: _recommendations,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 30)),
              ],
            ),
    );
  }
}
