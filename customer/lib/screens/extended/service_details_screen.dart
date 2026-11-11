import '../../repositories/auth_repository.dart';
import '../../services/customer_access.dart';

import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/service_share_link.dart';
import '../../widgets/customer_address_card.dart';
import '../../widgets/common/added_services_icon.dart';
import '../../widgets/reviews/service_reviews_section.dart';
import '../../repositories/service_cart_repository.dart';
import 'service_cart_screen.dart';
import '../../widgets/service_details/service_business_card.dart';
import '../../widgets/common/global_search_bar.dart';
import 'search_screen.dart';
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
  final _searchInput = TextEditingController();
  Map<String, dynamic> _overview = {};
  late ServiceModel _service;
  bool _available = true;
  @override
  Set<String> get liveDatasets => {
    'own:customer_service_collections',
    'local_saved_services',
    'public:services',
    'public:businesses',
    'public:vendors',
    'public:service_reviews',
    'public:service_metrics',
    'own:bookings',
  };
  @override
  Future<void> onLiveData(Set<String> changed) async {
    if (changed.contains('own:customer_service_collections') ||
        changed.contains('local_saved_services')) {
      await _loadFavorite();
    }
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
    await Future.wait([
      _recommendations.refresh(),
      _relatedVendors.refresh(),
      _loadOverview(),
    ]);
  }

  late final RecommendationController _recommendations;
  late final RecommendationController _relatedVendors;
  StreamSubscription? _authChanges;
  String? _accountId;
  bool _isFavorite = false;
  bool _savingFavorite = true;
  SavedServicesRepository get _saved => SavedServicesRepository();
  @override
  void initState() {
    super.initState();
    _service = widget.service;
    _accountId = AuthRepository().currentUser?.id;
    _authChanges = AuthRepository().authStateChanges.listen((state) {
      final next = state.session?.user.id;
      if (next != _accountId && mounted) {
        _accountId = next;
        setState(() => _isFavorite = false);
        unawaited(_loadFavorite());
      }
    });
    final recommendations = RecommendationRepository();
    _recommendations = RecommendationController(
      repository: recommendations,
      serviceId: widget.service.id,
    );
    _relatedVendors = RecommendationController(
      repository: recommendations,
      serviceId: widget.service.id,
      vendors: true,
    );
    unawaited(_relatedVendors.refresh());
    // Load related items immediately; recording interest is independent of this query.
    unawaited(_recommendations.refresh());
    unawaited(recommendations.signal(widget.service.id, 'view'));
    _loadFavorite();
    _loadOverview();
  }

  @override
  void dispose() {
    _authChanges?.cancel();
    _searchInput.dispose();
    _relatedVendors.dispose();
    _recommendations.dispose();
    super.dispose();
  }

  Future<void> _loadOverview() async {
    try {
      final overview = await ServiceRepository().getPublicOverview(_service.id);
      if (mounted) setState(() => _overview = overview);
    } catch (_) {
      /* Keep the service content visible while offline. */
    }
  }

  bool _sharing = false;
  Future<void> _shareService() async {
    if (_sharing) return;
    final link = serviceShareLink(_service.id);
    if (link == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppSettingsScope.translate(
              context,
              "customer.service_link_sharing_will_be_available_soon.29959698",
            ),
          ),
        ),
      );
      return;
    }
    _sharing = true;
    try {
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          text: '${_service.name} on Eventor\n$link',
          subject: _service.name,
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppSettingsScope.translate(
                context,
                "customer.unable_to_share_this_service_please_retry.240a00f5",
              ),
            ),
          ),
        );
      }
    } finally {
      _sharing = false;
    }
  }

  Future<void> _loadFavorite() async {
    if (!CustomerAccess.signedIn) {
      if (mounted) {
        setState(() {
          _isFavorite = false;
          _savingFavorite = false;
        });
      }
      return;
    }
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
    if (!await CustomerAccess.requireSignIn(context) || !mounted) return;
    setState(() => _savingFavorite = true);
    try {
      final next = !_isFavorite;
      await _saved.setSaved(_service, next);
      if (mounted) setState(() => _isFavorite = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppSettingsScope.translate(
                context,
                "customer.unable_to_save_service_please_retry.6b0df8d7",
              ),
            ),
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

  bool _addingService = false;
  Future<void> _addService() async {
    if (_addingService) return;
    if (!await CustomerAccess.requireSignIn(context) || !mounted) return;
    setState(() => _addingService = true);
    try {
      await ServiceCartRepository().add(_service.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppSettingsScope.translate(
              context,
              "customer.service_added_to_added_services.729ab85f",
            ),
          ),
          action: SnackBarAction(
            label: AppSettingsScope.translate(
              context,
              "customer.view_services.85affc5b",
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ServiceCartScreen(),
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppSettingsScope.translate(
                context,
                "customer.unable_to_add_service_sign_in_and_try_again.fb1bbeb7",
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _addingService = false);
    }
  }

  // ============================================================
  // BOOK SERVICE
  // ============================================================

  Future<void> _bookService() async {
    if (!_available) return;
    if (!await CustomerAccess.requireSignIn(context) || !mounted) return;
    setState(() {});
    final bool? bookingCreated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => BookingScreen(service: _service)),
    );

    if (!mounted) {
      return;
    }

    if (bookingCreated == true) {
      RecommendationRepository.changes.value++;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppSettingsScope.translate(
              context,
              "customer.booking_request_created_successfully.c1bffa19",
            ),
          ),
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
      backgroundColor: const Color(0xFFF8F8FA),

      // ========================================================
      // FIXED BOTTOM ACTION BAR
      // ========================================================
      bottomNavigationBar: !_available
          ? null
          : ServiceActionBar(
              onAddService: _addService,
              adding: _addingService,
              onBookService: _bookService,
            ),

      // ========================================================
      // SCREEN CONTENT
      // ========================================================
      body: !_available
          ? Center(
              child: Text(
                AppSettingsScope.translate(
                  context,
                  "customer.this_service_is_no_longer_available.bf16bb61",
                ),
              ),
            )
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

                  title: GlobalSearchBar(
                    controller: _searchInput,
                    onChanged: (_) {},
                    hintText: AppSettingsScope.translate(
                      context,
                      "customer.search_services_vendors_or_events.c4e70feb",
                    ),
                    readOnly: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const CustomerSearchScreen(),
                      ),
                    ),
                  ),
                  toolbarHeight: 66,
                  titleSpacing: 0,
                  actions: [
                    IconButton(
                      tooltip: AppSettingsScope.translate(
                        context,
                        "customer.added_services.b446b9aa",
                      ),
                      icon: const AddedServicesIcon(),
                      onPressed: () => CustomerAccess.open(
                        context,
                        const ServiceCartScreen(),
                      ),
                    ),
                  ],
                ),

                // ======================================================
                // GALLERY
                // ======================================================
                SliverToBoxAdapter(
                  child: ServiceGallery(
                    gallery: service.gallery,
                    isSaved: _isFavorite,
                    saving: _savingFavorite,
                    onSave: _toggleFavorite,
                    onShare: _shareService,
                  ),
                ),

                // ======================================================
                // SERVICE INFO
                // ======================================================
                SliverToBoxAdapter(
                  child: ServiceInfoSection(
                    service: service,
                    overview: _overview,
                  ),
                ),

                // ======================================================
                // DESCRIPTION
                // ======================================================
                SliverToBoxAdapter(
                  child: ServiceDescriptionSection(service: service),
                ),
                SliverToBoxAdapter(
                  child: ServiceBusinessCard(
                    data: _overview['business_summary'] is Map
                        ? Map<String, dynamic>.from(
                            _overview['business_summary'] as Map,
                          )
                        : const {},
                  ),
                ),

                if (CustomerAccess.signedIn)
                  const SliverToBoxAdapter(child: CustomerAddressCard()),

                // ======================================================
                // BOTTOM SPACE
                // ======================================================
                SliverToBoxAdapter(
                  child: ServiceRecommendationsSection(
                    controller: _recommendations,
                  ),
                ),
                SliverToBoxAdapter(
                  child: ServiceRecommendationsSection(
                    controller: _relatedVendors,
                  ),
                ),
                SliverToBoxAdapter(
                  child: ServiceReviewsSection(serviceId: service.id),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 30)),
              ],
            ),
    );
  }
}
