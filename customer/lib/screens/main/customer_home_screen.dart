import '../../services/app_live_data.dart';
import '../../repositories/recommendation_repository.dart';
import '../../widgets/recommendations/service_recommendations_section.dart';
import '../extended/search_screen.dart';
import '../../repositories/home_feed_repository.dart';
import '../../widgets/home_feed_widgets.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/banner_model.dart';
import '../../repositories/banner_repository.dart';

import 'bookings_screen.dart';
import 'explore_screen.dart';
import 'me_screen.dart';

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
    'public:event_types',
    'own:recommendations',
    'own:bookings',
    'own:customers',
  };
  @override
  Future<void> onLiveData(Set<String> changed) async {
    final work = <Future<void>>[];
    if (changed.contains('public:banners')) work.add(_loadBanners());
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

  static const Color gold = Color(0xFFFFCB48);

  static const Color softRose = Color(0xFFF5E8EC);

  static const Color background = Color(0xFFF8F8FA);

  static const Color textGrey = Color(0xFF73737D);

  // ===========================================================================
  // REPOSITORY
  // ===========================================================================

  final BannerRepository _bannerRepository = BannerRepository();

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

  final PageController _bannerPageController = PageController();

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

      final int nextIndex = (_currentBannerIndex + 1) % _banners.length;

      _bannerPageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
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
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => BookingsScreen()));
        break;

      case 'me':
      case 'profile':
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const MeScreen()));
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primaryWine, wineDark],
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: primaryWine.withValues(alpha: 0.28),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -------------------------------------------------------------------
            // TOP ROW
            // -------------------------------------------------------------------

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.stars_rounded, color: gold, size: 13),
                            SizedBox(width: 5),
                            Text(
                              'EVENT CONCIERGE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'EVENTOR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),

                Material(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // -------------------------------------------------------------------
            // SEARCH BAR
            // -------------------------------------------------------------------
            Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openSearch,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: softRose,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.search_rounded,
                            color: primaryWine,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Search services, vendors or events',
                            style: TextStyle(
                              fontSize: 13,
                              color: textGrey,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: primaryWine.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: primaryWine,
                            size: 17,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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

          SizedBox(
            height: 215,
            child: PageView.builder(
              controller: _bannerPageController,
              itemCount: _banners.length,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                if (!mounted) {
                  return;
                }

                setState(() {
                  _currentBannerIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final BannerModel banner = _banners[index];

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
          if (_banners.length > 1)
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Explore Now',
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
        height: 215,
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
