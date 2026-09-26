import 'package:flutter/material.dart';

import '../../models/service_model.dart';
import '../../repositories/service_repository.dart';
import '../extended/service_details_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({
    super.key,
  });

  @override
  State<DiscoverScreen> createState() =>
      _DiscoverScreenState();
}

class _DiscoverScreenState
    extends State<DiscoverScreen> {
  // ===========================================================================
  // COLORS
  // ===========================================================================

  static const Color primaryRed =
      Color(0xFF9F0101);

  static const Color lightRed =
      Color(0xFFFFE4E4);

  // ignore: unused_field
  static const Color softRed =
      Color(0xFFFFF1F1);

  static const Color textDark =
      Color(0xFF202020);

  static const Color textGrey =
      Color(0xFF777777);

  static const Color background =
      Color(0xFFF8F8F8);

  // ===========================================================================
  // REPOSITORY
  // ===========================================================================

  final ServiceRepository
      _serviceRepository =
      ServiceRepository();

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  final TextEditingController
      _searchController =
      TextEditingController();

  // ===========================================================================
  // STATE
  // ===========================================================================

  List<ServiceModel> _services = [];

  bool _isLoading = true;

  String? _errorMessage;

  String _searchQuery = '';

  // ===========================================================================
  // STATIC CATEGORY DATA
  // ===========================================================================

  final List<_CategoryData>
      _categories = const [
    _CategoryData(
      name: 'Wedding',
      icon: Icons.favorite_rounded,
    ),
    _CategoryData(
      name: 'Birthday',
      icon: Icons.cake_rounded,
    ),
    _CategoryData(
      name: 'Corporate',
      icon: Icons.business_rounded,
    ),
    _CategoryData(
      name: 'Baby Shower',
      icon: Icons.child_friendly_rounded,
    ),
    _CategoryData(
      name: 'Engagement',
      icon: Icons.diamond_rounded,
    ),
    _CategoryData(
      name: 'Anniversary',
      icon: Icons.card_giftcard_rounded,
    ),
  ];

  // ===========================================================================
  // EVENT DATA
  // ===========================================================================

  final List<_EventData> _events =
      const [
    _EventData(
      title: 'Wedding Planning',
      subtitle:
          'Photography • Catering • Decoration',
      icon: Icons.favorite_rounded,
    ),
    _EventData(
      title: 'Celebrations',
      subtitle:
          'Birthday • Anniversary • Parties',
      icon: Icons.celebration_rounded,
    ),
    _EventData(
      title: 'Business Events',
      subtitle:
          'Corporate • Meetings • Conferences',
      icon: Icons.business_center_rounded,
    ),
  ];

  // ===========================================================================
  // INIT
  // ===========================================================================

  @override
  void initState() {
    super.initState();

    _searchController.addListener(
      _onSearchChanged,
    );

    _loadServices();
  }

  // ===========================================================================
  // DISPOSE
  // ===========================================================================

  @override
  void dispose() {
    _searchController.removeListener(
      _onSearchChanged,
    );

    _searchController.dispose();

    super.dispose();
  }

  // ===========================================================================
  // SEARCH
  // ===========================================================================

  void _onSearchChanged() {
    if (!mounted) return;

    setState(() {
      _searchQuery = _searchController
          .text
          .trim()
          .toLowerCase();
    });
  }

  // ===========================================================================
  // LOAD SERVICES
  // ===========================================================================

  Future<void> _loadServices() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<ServiceModel>
          services =
          await _serviceRepository
              .getActiveServices();

      if (!mounted) return;

      setState(() {
        _services = services;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            _cleanError(e);
      });
    }
  }

  // ===========================================================================
  // FILTERED SERVICES
  // ===========================================================================

  List<ServiceModel>
      get _filteredServices {
    if (_searchQuery.isEmpty) {
      return _services;
    }

    return _services.where(
      (ServiceModel service) {
        final String name =
            service.name
                .toLowerCase();

        final String description =
            service.description
                    ?.toLowerCase() ??
                '';

        final String slug =
            service.slug
                .toLowerCase();

        final String category =
            service.categoryName
                    ?.toLowerCase() ??
                '';

        return name.contains(
              _searchQuery,
            ) ||
            description.contains(
              _searchQuery,
            ) ||
            slug.contains(
              _searchQuery,
            ) ||
            category.contains(
              _searchQuery,
            );
      },
    ).toList();
  }

  // ===========================================================================
  // ERROR
  // ===========================================================================

  String _cleanError(
    Object error,
  ) {
    return error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        );
  }

  // ===========================================================================
  // OPEN SERVICE
  // ===========================================================================

  void _openServiceDetails(
    ServiceModel service,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ServiceDetailsScreen(
          service: service,
        ),
      ),
    );
  }

  // ===========================================================================
  // CATEGORY TAP
  // ===========================================================================

  void _selectCategory(
    String category,
  ) {
    _searchController.text =
        category;

    _searchController.selection =
        TextSelection.collapsed(
      offset:
          _searchController.text
              .length,
    );
  }

  // ===========================================================================
  // SEARCH BAR
  // ===========================================================================

  Widget _buildSearchBar() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color:
              Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.035,
            ),
            blurRadius: 8,
            offset: const Offset(
              0,
              2,
            ),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
          ),

          const Icon(
            Icons.search_rounded,
            size: 21,
            color: textGrey,
          ),

          const SizedBox(
            width: 9,
          ),

          Expanded(
            child: TextField(
              controller:
                  _searchController,
              textInputAction:
                  TextInputAction.search,
              decoration:
                  const InputDecoration(
                border:
                    InputBorder.none,
                hintText:
                    'Search services, vendors, or events...',
                hintStyle:
                    TextStyle(
                  fontSize: 11,
                  color: textGrey,
                ),
                isDense: true,
              ),
              style:
                  const TextStyle(
                fontSize: 12,
                color: textDark,
              ),
            ),
          ),

          if (_searchQuery
              .isNotEmpty)
            IconButton(
              onPressed: () {
                _searchController
                    .clear();
              },
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
              ),
              color: textGrey,
              splashRadius: 18,
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION TITLE
  // ===========================================================================

  Widget _buildSectionTitle(
    String title, {
    VoidCallback? onSeeAll,
  }) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        17,
        16,
        9,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style:
                  const TextStyle(
                fontSize: 15,
                fontWeight:
                    FontWeight.w700,
                color: textDark,
              ),
            ),
          ),

          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Text(
                'See all',
                style:
                    TextStyle(
                  fontSize: 10,
                  fontWeight:
                      FontWeight.w600,
                  color: primaryRed,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CATEGORY CARD
  // ===========================================================================

  Widget _buildCategoryCard(
    _CategoryData category,
  ) {
    return GestureDetector(
      onTap: () {
        _selectCategory(
          category.name,
        );
      },
      child: SizedBox(
        width: 62,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration:
                  BoxDecoration(
                color: _categoryColor(
                  category.name,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(
                      alpha: 0.04,
                    ),
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                category.icon,
                size: 20,
                color: Colors.white,
              ),
            ),

            const SizedBox(
              height: 6,
            ),

            Text(
              category.name,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontSize: 8.5,
                fontWeight:
                    FontWeight.w600,
                color: textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // CATEGORY COLOR
  // ===========================================================================

  Color _categoryColor(
    String category,
  ) {
    switch (category) {
      case 'Wedding':
        return const Color(
          0xFFE04B4B,
        );

      case 'Birthday':
        return const Color(
          0xFFF39A24,
        );

      case 'Corporate':
        return const Color(
          0xFF4568C5,
        );

      case 'Baby Shower':
        return const Color(
          0xFF9748B8,
        );

      case 'Engagement':
        return const Color(
          0xFF36A879,
        );

      case 'Anniversary':
        return const Color(
          0xFFE9654B,
        );

      default:
        return primaryRed;
    }
  }

  // ===========================================================================
  // EVENT CARD
  // ===========================================================================

  Widget _buildEventCard(
    _EventData event,
  ) {
    return GestureDetector(
      onTap: () {
        _selectCategory(
          event.title,
        );
      },
      child: Container(
        width: 142,
        margin:
            const EdgeInsets.only(
          right: 10,
        ),
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(
            12,
          ),
          border: Border.all(
            color:
                const Color(0xFFFFDADA),
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(
                alpha: 0.035,
              ),
              blurRadius: 6,
              offset: const Offset(
                0,
                2,
              ),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              height: 72,
              decoration:
                  const BoxDecoration(
                color:
                    primaryRed,
                borderRadius:
                    BorderRadius.vertical(
                  top:
                      Radius.circular(
                    12,
                  ),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 10,
                    top: 9,
                    child: Icon(
                      event.icon,
                      size: 35,
                      color: Colors.white
                          .withValues(
                        alpha: 0.9,
                      ),
                    ),
                  ),

                  const Positioned(
                    left: 10,
                    bottom: 9,
                    child: Text(
                      'Explore',
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                        fontSize: 9,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding:
                  const EdgeInsets
                      .fromLTRB(
                9,
                8,
                8,
                9,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 10,
                      fontWeight:
                          FontWeight.w700,
                      color:
                          textDark,
                    ),
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  Text(
                    event.subtitle,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 7.5,
                      color:
                          textGrey,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // FEATURED SERVICE CARD
  // ===========================================================================

  Widget _buildFeaturedServiceCard(
    ServiceModel service,
  ) {
    final String category =
        service.categoryName
                ?.trim()
                .isNotEmpty ==
            true
        ? service.categoryName!
        : 'Service';

    return GestureDetector(
      onTap: () {
        _openServiceDetails(
          service,
        );
      },
      child: Container(
        width: 132,
        margin:
            const EdgeInsets.only(
          right: 10,
        ),
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(
            12,
          ),
          border: Border.all(
            color:
                Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(
                alpha: 0.035,
              ),
              blurRadius: 6,
              offset: const Offset(
                0,
                2,
              ),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // -----------------------------------------------------------------
            // IMAGE PLACEHOLDER
            // -----------------------------------------------------------------

            Container(
              height: 72,
              width: double.infinity,
              decoration:
                  const BoxDecoration(
                color: lightRed,
                borderRadius:
                    BorderRadius.vertical(
                  top:
                      Radius.circular(
                    12,
                  ),
                ),
              ),
              child: Center(
                child: Icon(
                  _serviceIcon(
                    category,
                  ),
                  size: 25,
                  color: primaryRed,
                ),
              ),
            ),

            Padding(
              padding:
                  const EdgeInsets
                      .fromLTRB(
                8,
                7,
                8,
                8,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  // -----------------------------------------------------------
                  // CATEGORY
                  // -----------------------------------------------------------

                  Text(
                    category,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 7,
                      color:
                          primaryRed,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  const SizedBox(
                    height: 3,
                  ),

                  // -----------------------------------------------------------
                  // NAME
                  // -----------------------------------------------------------

                  Text(
                    service.name,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 9.5,
                      fontWeight:
                          FontWeight.w700,
                      color:
                          textDark,
                    ),
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  // -----------------------------------------------------------
                  // DESCRIPTION
                  // -----------------------------------------------------------

                  Text(
                    service.description ??
                        'Professional event service',
                    maxLines: 2,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 7,
                      color:
                          textGrey,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SERVICE ICON
  // ===========================================================================

  IconData _serviceIcon(
    String category,
  ) {
    final String value =
        category.toLowerCase();

    if (value.contains('photo')) {
      return Icons
          .photo_camera_rounded;
    }

    if (value.contains('cater')) {
      return Icons
          .restaurant_rounded;
    }

    if (value.contains('decor')) {
      return Icons
          .auto_awesome_rounded;
    }

    if (value.contains('music')) {
      return Icons
          .music_note_rounded;
    }

    if (value.contains('venue')) {
      return Icons
          .location_city_rounded;
    }

    if (value.contains('makeup')) {
      return Icons
          .face_retouching_natural;
    }

    return Icons
        .miscellaneous_services_rounded;
  }

  // ===========================================================================
  // POPULAR SERVICE CARD
  // ===========================================================================

  Widget _buildPopularCard(
    ServiceModel service,
  ) {
    return GestureDetector(
      onTap: () {
        _openServiceDetails(
          service,
        );
      },
      child: Container(
        width: 154,
        margin:
            const EdgeInsets.only(
          right: 10,
        ),
        padding:
            const EdgeInsets.all(10),
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(
            13,
          ),
          border: Border.all(
            color:
                Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(
                alpha: 0.035,
              ),
              blurRadius: 7,
              offset: const Offset(
                0,
                2,
              ),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration:
                      BoxDecoration(
                    color: lightRed,
                    borderRadius:
                        BorderRadius
                            .circular(
                      9,
                    ),
                  ),
                  child: const Icon(
                    Icons
                        .storefront_rounded,
                    size: 17,
                    color:
                        primaryRed,
                  ),
                ),

                const Spacer(),

                Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration:
                      BoxDecoration(
                    color: lightRed,
                    borderRadius:
                        BorderRadius
                            .circular(
                      8,
                    ),
                  ),
                  child:
                      const Text(
                    'Popular',
                    style:
                        TextStyle(
                      fontSize: 6.5,
                      color:
                          primaryRed,
                      fontWeight:
                          FontWeight
                              .w700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 9,
            ),

            Text(
              service.name,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                fontSize: 10,
                fontWeight:
                    FontWeight.w700,
                color: textDark,
              ),
            ),

            const SizedBox(
              height: 4,
            ),

            Text(
              service.categoryName ??
                  'Event Service',
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                fontSize: 7.5,
                color: textGrey,
              ),
            ),

            const Spacer(),

            Row(
              children: [
                const Icon(
                  Icons
                      .arrow_forward_rounded,
                  size: 14,
                  color:
                      primaryRed,
                ),

                const SizedBox(
                  width: 4,
                ),

                const Text(
                  'View service',
                  style:
                      TextStyle(
                    fontSize: 7,
                    fontWeight:
                        FontWeight.w600,
                    color:
                        primaryRed,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TRENDING BANNER
  // ===========================================================================

  Widget _buildTrendingBanner() {
    return Container(
      margin:
          const EdgeInsets.fromLTRB(
        16,
        17,
        16,
        18,
      ),
      padding:
          const EdgeInsets.fromLTRB(
        14,
        13,
        14,
        13,
      ),
      decoration:
          BoxDecoration(
        color: primaryRed,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        boxShadow: [
          BoxShadow(
            color:
                primaryRed.withValues(
              alpha: 0.18,
            ),
            blurRadius: 10,
            offset: const Offset(
              0,
              4,
            ),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration:
                BoxDecoration(
              color:
                  Colors.white
                      .withValues(
                alpha: 0.15,
              ),
              shape:
                  BoxShape.circle,
            ),
            child: const Icon(
              Icons
                  .local_fire_department_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  'Trending This Week',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                SizedBox(
                  height: 3,
                ),

                Text(
                  'Popular services customers are exploring right now.',
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      TextStyle(
                    color:
                        Colors.white70,
                    fontSize: 7.5,
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons
                .arrow_forward_ios_rounded,
            color: Colors.white,
            size: 14,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // LOADING
  // ===========================================================================

  Widget _buildLoading() {
    return const Center(
      child:
          CircularProgressIndicator(
        color: primaryRed,
      ),
    );
  }

  // ===========================================================================
  // ERROR
  // ===========================================================================

  Widget _buildError() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          30,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration:
                  BoxDecoration(
                color: lightRed,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons
                    .cloud_off_rounded,
                color:
                    primaryRed,
                size: 34,
              ),
            ),

            const SizedBox(
              height: 15,
            ),

            const Text(
              'Unable to load Discover',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.w700,
                color: textDark,
              ),
            ),

            const SizedBox(
              height: 7,
            ),

            Text(
              _errorMessage ??
                  'Something went wrong.',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontSize: 11,
                color: textGrey,
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            ElevatedButton(
              onPressed:
                  _loadServices,
              style:
                  ElevatedButton
                      .styleFrom(
                backgroundColor:
                    primaryRed,
                foregroundColor:
                    Colors.white,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
              child:
                  const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // EMPTY
  // ===========================================================================

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          30,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 50,
              color: textGrey,
            ),

            const SizedBox(
              height: 12,
            ),

            const Text(
              'No services found',
              style:
                  TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(
              height: 6,
            ),

            Text(
              'No service matches "$_searchQuery".',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontSize: 11,
                color: textGrey,
              ),
            ),

            const SizedBox(
              height: 15,
            ),

            TextButton(
              onPressed: () {
                _searchController
                    .clear();
              },
              child:
                  const Text(
                'Clear Search',
                style:
                    TextStyle(
                  color:
                      primaryRed,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // MAIN BODY
  // ===========================================================================

  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoading();
    }

    if (_errorMessage != null) {
      return _buildError();
    }

    final List<ServiceModel>
        services =
        _filteredServices;

    if (_searchQuery.isNotEmpty &&
        services.isEmpty) {
      return _buildEmpty();
    }

    final List<ServiceModel>
        featuredServices =
        services.take(8).toList();

    final List<ServiceModel>
        popularServices =
        services.take(6).toList();

    return RefreshIndicator(
      color: primaryRed,
      onRefresh:
          _loadServices,
      child: CustomScrollView(
        physics:
            const BouncingScrollPhysics(
          parent:
              AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // ===================================================================
          // TOP SEARCH
          // ===================================================================

          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                12,
                12,
                12,
                0,
              ),
              child:
                  _buildSearchBar(),
            ),
          ),

          // ===================================================================
          // SEARCH RESULT COUNT
          // ===================================================================

          if (_searchQuery
                  .isNotEmpty &&
              services.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  16,
                  8,
                  16,
                  0,
                ),
                child: Text(
                  '${services.length} services found',
                  style:
                      const TextStyle(
                    fontSize: 10,
                    color: textGrey,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ),

          // ===================================================================
          // POPULAR CATEGORIES
          // ===================================================================

          SliverToBoxAdapter(
            child:
                _buildSectionTitle(
              'Popular Categories',
              onSeeAll: () {},
            ),
          ),

          SliverToBoxAdapter(
            child: SizedBox(
              height: 82,
              child:
                  ListView.builder(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 16,
                ),
                scrollDirection:
                    Axis.horizontal,
                physics:
                    const BouncingScrollPhysics(),
                itemCount:
                    _categories.length,
                itemBuilder:
                    (context, index) {
                  return Padding(
                    padding:
                        const EdgeInsets
                            .only(
                      right: 10,
                    ),
                    child:
                        _buildCategoryCard(
                      _categories[
                          index],
                    ),
                  );
                },
              ),
            ),
          ),

          // ===================================================================
          // EXPLORE BY EVENT
          // ===================================================================

          SliverToBoxAdapter(
            child:
                _buildSectionTitle(
              'Explore by Event',
              onSeeAll: () {},
            ),
          ),

          SliverToBoxAdapter(
            child: SizedBox(
              height: 122,
              child:
                  ListView.builder(
                padding:
                    const EdgeInsets
                        .only(
                  left: 16,
                ),
                scrollDirection:
                    Axis.horizontal,
                physics:
                    const BouncingScrollPhysics(),
                itemCount:
                    _events.length,
                itemBuilder:
                    (context, index) {
                  return _buildEventCard(
                    _events[index],
                  );
                },
              ),
            ),
          ),

          // ===================================================================
          // FEATURED SERVICES
          // ===================================================================

          SliverToBoxAdapter(
            child:
                _buildSectionTitle(
              'Featured Services',
              onSeeAll:
                  featuredServices
                          .isEmpty
                      ? null
                      : () {},
            ),
          ),

          SliverToBoxAdapter(
            child:
                featuredServices.isEmpty
                    ? _buildSmallEmpty(
                        'No featured services available',
                      )
                    : SizedBox(
                        height: 155,
                        child:
                            ListView.builder(
                          padding:
                              const EdgeInsets
                                  .only(
                            left: 16,
                          ),
                          scrollDirection:
                              Axis.horizontal,
                          physics:
                              const BouncingScrollPhysics(),
                          itemCount:
                              featuredServices
                                  .length,
                          itemBuilder:
                              (
                            context,
                            index,
                          ) {
                            return _buildFeaturedServiceCard(
                              featuredServices[
                                  index],
                            );
                          },
                        ),
                      ),
          ),

          // ===================================================================
          // POPULAR NEAR YOU
          // ===================================================================

          SliverToBoxAdapter(
            child:
                _buildSectionTitle(
              'Popular Near You',
              onSeeAll:
                  popularServices
                          .isEmpty
                      ? null
                      : () {},
            ),
          ),

          SliverToBoxAdapter(
            child:
                popularServices.isEmpty
                    ? _buildSmallEmpty(
                        'Services will appear here when vendors publish them',
                      )
                    : SizedBox(
                        height: 128,
                        child:
                            ListView.builder(
                          padding:
                              const EdgeInsets
                                  .only(
                            left: 16,
                          ),
                          scrollDirection:
                              Axis.horizontal,
                          physics:
                              const BouncingScrollPhysics(),
                          itemCount:
                              popularServices
                                  .length,
                          itemBuilder:
                              (
                            context,
                            index,
                          ) {
                            return _buildPopularCard(
                              popularServices[
                                  index],
                            );
                          },
                        ),
                      ),
          ),

          // ===================================================================
          // TRENDING
          // ===================================================================

          const SliverToBoxAdapter(
            child:
                _TrendingSpacer(),
          ),

          SliverToBoxAdapter(
            child:
                _buildTrendingBanner(),
          ),

          // ===================================================================
          // BOTTOM SPACE
          // ===================================================================

          const SliverToBoxAdapter(
            child: SizedBox(
              height: 85,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SMALL EMPTY
  // ===========================================================================

  Widget _buildSmallEmpty(
    String text,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      child: Container(
        height: 60,
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(
            12,
          ),
        ),
        alignment:
            Alignment.center,
        child: Text(
          text,
          style:
              const TextStyle(
            fontSize: 9,
            color: textGrey,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          background,
      body: SafeArea(
        child: _buildContent(),
      ),
    );
  }
}

// =============================================================================
// CATEGORY MODEL
// =============================================================================

class _CategoryData {
  final String name;
  final IconData icon;

  const _CategoryData({
    required this.name,
    required this.icon,
  });
}

// =============================================================================
// EVENT MODEL
// =============================================================================

class _EventData {
  final String title;
  final String subtitle;
  final IconData icon;

  const _EventData({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

// =============================================================================
// TRENDING SPACER
// =============================================================================

class _TrendingSpacer
    extends StatelessWidget {
  const _TrendingSpacer();

  @override
  Widget build(
    BuildContext context,
  ) {
    return const SizedBox(
      height: 1,
    );
  }
}