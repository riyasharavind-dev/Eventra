import '../../services/customer_access.dart';

import 'package:eventor_customer/services/app_settings_controller.dart';

import '../../widgets/common/added_services_icon.dart';
import '../extended/service_cart_screen.dart';
import '../../services/app_live_data.dart';
import '../../repositories/recommendation_repository.dart';
import '../../widgets/recommendations/service_recommendations_section.dart';
import '../extended/search_screen.dart';
import '../../repositories/home_feed_repository.dart';
import '../../widgets/home_feed_widgets.dart';
import '../../widgets/home/home_trending_categories.dart';
import '../../repositories/explore_repository.dart';
import '../../models/explore_data.dart';
import '../../models/category_node_model.dart';
import '../../repositories/auth_repository.dart';
import '../../models/auth_model.dart';
import '../../widgets/common/global_search_bar.dart';
import '../extended/customer_notifications_screen.dart';
import '../extended/result_screen.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/banner_model.dart';
import '../../repositories/banner_repository.dart';

import 'bookings_screen.dart';
import 'explore_screen.dart';
import 'me_screen.dart';

const double _homeBannerAspectRatio = 16 / 9;

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen>
    with LiveDataState<CustomerHomeScreen> {
  @override
  Set<String> get liveDatasets => {
    'public:services',
    'public:businesses',
    'public:vendors',
    'public:service_reviews',
    'public:service_metrics',
    'public:banners',
    'public:home_feed_sections',
    'public:home_feed_pinned_items',
    'public:category_nodes',
    'public:category_trends',
    'public:event_types',
    'own:recommendations',
    'own:bookings',
    'own:customers',
  };
  @override
  Future<void> onLiveData(Set<String> changed) async {
    final work = <Future<void>>[];
    if (changed.contains('public:banners')) work.add(_loadBanners());
    if (changed.contains('public:category_nodes') ||
        changed.contains('public:category_trends')) {
      work.add(_loadTrendingCategories());
    }
    final catalog =
        changed.contains('own:customers') ||
        changed.any((d) => d.startsWith('public:') && d != 'public:banners');
    if (catalog) work.add(_feed.refresh(keepWindow: true));
    if (catalog ||
        changed.contains('own:recommendations') ||
        changed.contains('own:bookings')) {
      work.add(_recommendations.refresh());
    }
    await Future.wait(work);
  }

  // ===========================================================================
  // COLORS
  // ===========================================================================

  static const Color primaryWine = Color(0xFF80152C);

  static const Color wineDark = Color(0xFF5A0C1E);

  static const Color softRose = Color(0xFFF5E8EC);

  static const Color background = Color(0xFFF8F8FA);

  // ===========================================================================
  // REPOSITORY
  // ===========================================================================

  final BannerRepository _bannerRepository = BannerRepository();
  final ExploreRepository _exploreRepository = ExploreRepository();
  final AuthRepository _authRepository = AuthRepository();
  final TextEditingController _searchController = TextEditingController();
  AuthModel? _customerProfile;
  ExploreData? _exploreData;
  static const int _bannerLoopStart = 100000;

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  bool _openingSearch = false;
  Future<void> _openSearch() async {
    if (_openingSearch) return;
    _openingSearch = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const CustomerSearchScreen()),
      );
    } finally {
      _openingSearch = false;
    }
  }

  // ===========================================================================
  // BANNER
  // ===========================================================================

  final PageController _bannerPageController = PageController(
    initialPage: _bannerLoopStart,
  );

  final _feed = HomeFeedController();
  final _recommendations = RecommendationController(
    repository: RecommendationRepository(),
  );
  Timer? _bannerTimer;

  List<BannerModel> _banners = [];

  bool _isBannerLoading = true;

  int _currentBannerIndex = 0;

  // ===========================================================================
  // INIT
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    _loadBanners();
    _feed.refresh();
    _recommendations.refresh();
    _loadTrendingCategories();
    _loadCustomerProfile();
  }

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  @override
  void dispose() {
    _feed.dispose();
    _recommendations.dispose();
    _bannerTimer?.cancel();

    _bannerPageController.dispose();
    _searchController.dispose();

    super.dispose();
  }

  // ===========================================================================
  // LOAD BANNERS
  // ===========================================================================

  Future<void> _loadBanners() async {
    try {
      final List<BannerModel> banners = await _bannerRepository
          .getActiveBanners();

      if (!mounted) {
        return;
      }

      setState(() {
        _banners = banners;
        _isBannerLoading = false;
        _currentBannerIndex = 0;
      });
      if (banners.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _bannerPageController.hasClients) {
            _bannerPageController.jumpToPage(_bannerLoopStart);
          }
        });
      }
      _startBannerAutoSlide();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isBannerLoading = false;
        _banners = [];
      });

      debugPrint('Banner loading error: $e');
    }
  }

  // ===========================================================================
  // AUTO SLIDE
  // ===========================================================================

  void _startBannerAutoSlide() {
    _bannerTimer?.cancel();

    if (_banners.length <= 1) {
      return;
    }

    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_bannerPageController.hasClients || _banners.isEmpty) {
        return;
      }

      final int currentPage =
          _bannerPageController.page?.round() ?? _bannerLoopStart;
      _bannerPageController.animateToPage(
        currentPage + 1,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _loadCustomerProfile() async {
    try {
      final profile = await _authRepository.getAuthUser();
      if (mounted) setState(() => _customerProfile = profile);
    } catch (_) {
      // Keep a neutral avatar if the profile is not available yet.
    }
  }

  Future<void> _loadTrendingCategories() async {
    try {
      final data = await _exploreRepository.load();
      if (mounted) setState(() => _exploreData = data);
    } catch (_) {
      // Home remains usable if category ranking is temporarily unavailable.
    }
  }

  void _openCategory(CategoryNodeModel category) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ResultScreen(query: category.name, categoryId: category.id),
      ),
    );
  }

  Future<void> _openNotifications() async {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CustomerNotificationsScreen(),
      ),
    );
  }

  // ===========================================================================
  // BANNER CLICK
  // ===========================================================================

  Future<void> _onBannerTap(BannerModel banner) async {
    final String actionType = banner.actionType.trim().toLowerCase();

    final String actionValue = banner.actionValue?.trim() ?? '';

    // -------------------------------------------------------------------------
    // NO ACTION
    // -------------------------------------------------------------------------

    if (actionType == 'none' || actionValue.isEmpty) {
      return;
    }

    // -------------------------------------------------------------------------
    // INTERNAL SCREEN
    // -------------------------------------------------------------------------

    if (actionType == 'screen') {
      _openInternalScreen(actionValue);

      return;
    }

    // -------------------------------------------------------------------------
    // EXTERNAL URL
    // -------------------------------------------------------------------------

    if (actionType == 'url') {
      await _openExternalUrl(actionValue);

      return;
    }
  }

  // ===========================================================================
  // INTERNAL SCREEN NAVIGATION
  // ===========================================================================

  void _openInternalScreen(String value) {
    final String screen = value.toLowerCase().replaceAll('/', '').trim();

    switch (screen) {
      case 'discover': // Legacy banner target.
      case 'explore':
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ExploreScreen()));
        break;

      case 'bookings':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BookingsScreen()),
        );
        break;

      case 'me':
      case 'profile':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MeScreen()),
        );
        break;

      case 'home':
        break;

      default:
        _showMessage('This banner destination is not available yet.');
        break;
    }
  }

  // ===========================================================================
  // EXTERNAL URL
  // ===========================================================================

  Future<void> _openExternalUrl(String value) async {
    final Uri? uri = Uri.tryParse(value);

    if (uri == null || !uri.hasScheme) {
      _showMessage('Invalid banner URL.');

      return;
    }

    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        _showMessage('Could not open this link.');
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage('Could not open this link.');

      debugPrint('Banner URL error: $e');
    }
  }

  // ===========================================================================
  // REFRESH
  // ===========================================================================

  Future<void> _refreshHome() async {
    await Future.wait([
      _loadBanners(),
      _feed.refresh(),
      _recommendations.refresh(),
    ]);
  }

  // ===========================================================================
  // MESSAGE
  // ===========================================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: RefreshIndicator(
          color: primaryWine,
          onRefresh: _refreshHome,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.axis == Axis.vertical &&
                  n.metrics.extentAfter < 500 &&
                  _feed.error == null) {
                _feed.loadMore();
              }
              return false;
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // =================================================================
                // HEADER
                // =================================================================

                SliverToBoxAdapter(child: _buildHeader()),

                // =================================================================
                // HOME BANNERS
                // =================================================================
                if (_isBannerLoading)
                  const SliverToBoxAdapter(child: _BannerLoadingCard()),

                if (!_isBannerLoading && _banners.isNotEmpty)
                  SliverToBoxAdapter(child: _buildBannerSection()),

                // =================================================================
                // NO BANNER
                // =================================================================
                if (!_isBannerLoading && _banners.isEmpty)
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                if (_exploreData != null && _exploreData!.parents.isNotEmpty)
                  SliverToBoxAdapter(
                    child: HomeTrendingCategories(
                      categories: _exploreData!.parents,
                      scores: _exploreData!.categoryScores,
                      onTap: _openCategory,
                      onSeeAll: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ExploreScreen(),
                        ),
                      ),
                    ),
                  ),

                SliverToBoxAdapter(
                  child: ServiceRecommendationsSection(
                    controller: _recommendations,
                    listenToActivity: false,
                  ),
                ),
                HomeFeedSliver(controller: _feed),
                // BOTTOM SPACE
                // =================================================================

                const SliverToBoxAdapter(child: SizedBox(height: 128)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                key: const ValueKey('home-profile-button'),
                onTap: null,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: wineDark,
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _customerProfile?.avatarUrl?.trim().isNotEmpty == true
                      ? Image.network(
                          _customerProfile!.avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, error, stack) => const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 25,
                          ),
                        )
                      : const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 25,
                        ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: AppSettingsScope.translate(
                  context,
                  "customer.added_services.b446b9aa",
                ),
                icon: const AddedServicesIcon(color: Color(0xFF17171B)),
                onPressed: () =>
                    CustomerAccess.open(context, const ServiceCartScreen()),
              ),
              const SizedBox(width: 8),
              _HomeHeaderAction(
                tooltip: AppSettingsScope.translate(
                  context,
                  "customer.notifications.78801183",
                ),
                icon: Icons.notifications_none_rounded,
                onTap: _openNotifications,
                showDot: CustomerAccess.signedIn,
              ),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 13),
          GlobalSearchBar(
            controller: _searchController,
            onChanged: (_) {},
            hintText: AppSettingsScope.translate(
              context,
              "customer.search_services_vendors_or_events.c4e70feb",
            ),
            readOnly: true,
            onTap: _openSearch,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BANNER SECTION
  // ===========================================================================

  Widget _buildBannerSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        children: [
          // ---------------------------------------------------------------------
          // BANNER
          // ---------------------------------------------------------------------

          AspectRatio(
            aspectRatio: _homeBannerAspectRatio,
            child: PageView.builder(
              controller: _bannerPageController,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                if (!mounted) {
                  return;
                }

                setState(() {
                  _currentBannerIndex = index % _banners.length;
                });
              },
              itemBuilder: (context, index) {
                final BannerModel banner = _banners[index % _banners.length];

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _buildBannerCard(banner),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // ---------------------------------------------------------------------
          // DOT INDICATOR
          // ---------------------------------------------------------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_banners.length, (index) {
              final bool selected = index == _currentBannerIndex;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 6,
                width: selected ? 24 : 6,
                decoration: BoxDecoration(
                  color: selected
                      ? primaryWine
                      : primaryWine.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BANNER CARD
  // ===========================================================================

  Widget _buildBannerCard(BannerModel banner) {
    final bool hasAction = banner.actionType.trim().toLowerCase() != 'none';

    return GestureDetector(
      onTap: () => _onBannerTap(banner),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF0EDF0), width: 1),
          boxShadow: [
            BoxShadow(
              color: primaryWine.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // -------------------------------------------------------------------
            // BANNER IMAGE
            // -------------------------------------------------------------------

            Image.network(
              banner.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: softRose,
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: primaryWine,
                      size: 44,
                    ),
                  ),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }

                return Container(
                  color: softRose.withValues(alpha: 0.5),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: primaryWine,
                      strokeWidth: 2.5,
                    ),
                  ),
                );
              },
            ),

            // -------------------------------------------------------------------
            // GRADIENT OVER IMAGE
            // -------------------------------------------------------------------
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.4, 1.0],
                  colors: [Colors.transparent, Color(0xCC170208)],
                ),
              ),
            ),

            // -------------------------------------------------------------------
            // EXPLORE NOW BUTTON
            // -------------------------------------------------------------------
            if (hasAction)
              Positioned(
                right: 16,
                bottom: 14,
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () => _onBannerTap(banner),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primaryWine,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppSettingsScope.translate(
                            context,
                            "customer.explore_now.71f3ebe9",
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BannerLoadingCard extends StatelessWidget {
  const _BannerLoadingCard();

  static const Color primaryWine = Color(0xFF80152C);
  static const Color softRose = Color(0xFFF5E8EC);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Container(
        height:
            (MediaQuery.sizeOf(context).width - 32) / _homeBannerAspectRatio,
        decoration: BoxDecoration(
          color: softRose.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF0EDF0), width: 1),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: primaryWine,
            strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// CATEGORY CARD
// =============================================================================

class _HomeHeaderAction extends StatelessWidget {
  const _HomeHeaderAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tooltip,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(icon, color: const Color(0xFF17171B), size: 25),
              ),
              if (showDot)
                Positioned(
                  right: 5,
                  top: 5,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB51235),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.3),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
