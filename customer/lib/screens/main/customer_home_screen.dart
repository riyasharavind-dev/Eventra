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

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  // ===========================================================================
  // COLORS
  // ===========================================================================

  static const Color primaryRed = Color(0xFF9F0101);

  static const Color background = Color(0xFFF8F8F8);

  static const Color textDark = Color(0xFF202020);

  static const Color textGrey = Color(0xFF777777);

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
  }

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  @override
  void dispose() {
    _feed.dispose();
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
    await Future.wait([_loadBanners(), _feed.refresh()]);
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
          color: primaryRed,
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF9F0101), Color(0xFFC00000)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: primaryRed.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, 7),
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
                const Expanded(
                  child: Text(
                    'EVENTRA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                Material(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {},
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // -------------------------------------------------------------------
            // SEARCH BAR
            // -------------------------------------------------------------------
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                readOnly: true,
                showCursor: false,
                onTap: _openSearch,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 14, color: textDark),
                decoration: InputDecoration(
                  hintText: 'Search services, vendors or events',
                  hintStyle: const TextStyle(fontSize: 13, color: textGrey),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: textGrey,
                    size: 23,
                  ),
                  suffixIcon: IconButton(
                    onPressed: _openSearch,
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      color: primaryRed,
                      size: 21,
                    ),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        children: [
          // ---------------------------------------------------------------------
          // BANNER
          // ---------------------------------------------------------------------

          SizedBox(
            height: 205,
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
                  padding: const EdgeInsets.only(right: 4),
                  child: _buildBannerCard(banner),
                );
              },
            ),
          ),

          const SizedBox(height: 9),

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
                  width: selected ? 20 : 6,
                  decoration: BoxDecoration(
                    color: selected ? primaryRed : Colors.grey.shade300,
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
  //
  // CHANGES:
  // 1. Title removed
  // 2. Subtitle removed
  // 3. Explore Now button moved to bottom-right
  //
  // ===========================================================================

  Widget _buildBannerCard(BannerModel banner) {
    final bool hasAction = banner.actionType.trim().toLowerCase() != 'none';

    return GestureDetector(
      onTap: () => _onBannerTap(banner),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 5),
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
                  color: const Color(0xFFF5D0D0),
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: primaryRed,
                      size: 48,
                    ),
                  ),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }

                return Container(
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: primaryRed,
                      strokeWidth: 2,
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
                  stops: [0.35, 1.0],
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),

            // -------------------------------------------------------------------
            // EXPLORE NOW BUTTON
            // -------------------------------------------------------------------
            //
            // Title + subtitle completely removed.
            // Button is positioned on the RIGHT side.
            //
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
                      foregroundColor: primaryRed,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Explore Now  →',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
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
  // SECTION HEADER
  // ===========================================================================
}

class _BannerLoadingCard extends StatelessWidget {
  const _BannerLoadingCard();

  static const Color primaryRed = Color(0xFF9F0101);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Container(
        height: 205,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: primaryRed, strokeWidth: 2),
        ),
      ),
    );
  }
}

// =============================================================================
// CATEGORY CARD
// =============================================================================
