import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// EVENTRA BOOKING COLORS
// ============================================================================

class EventraBookingColors {
  static const Color primaryRed = Color(0xFF9F0101);
  static const Color lightRed = Color(0xFFFFE8E8);
  static const Color background = Color(0xFFF8F8F8);
  static const Color textDark = Color(0xFF202020);
  static const Color textGrey = Color(0xFF777777);

  const EventraBookingColors._();
}

// ============================================================================
// BOOKINGS SCREEN
// ============================================================================

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({
    super.key,
  });

  @override
  State<BookingsScreen> createState() =>
      _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  // ==========================================================================
  // DATA
  // ==========================================================================

  List<Map<String, dynamic>> _bookings = [];

  bool _isLoading = true;

  String? _errorMessage;

  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'Upcoming',
    'Completed',
    'Cancelled',
  ];

  // ==========================================================================
  // INIT
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  // ==========================================================================
  // LOAD BOOKINGS
  // ==========================================================================

  Future<void> _loadBookings() async {
    final User? user = _supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Please login to view your bookings.';
      });

      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await _supabase
          .from('bookings')
          .select('''
            id,
            customer_id,
            vendor_id,
            service_id,
            event_type_id,
            event_date,
            guest_count,
            location,
            requirement,
            price,
            status,
            created_at,

            services (
              id,
              name,
              gallery
            ),

            vendors (
              id,
              name,
              email
            ),

            event_types (
              id,
              name
            )
          ''')
          .eq(
            'customer_id',
            user.id,
          )
          .order(
            'created_at',
            ascending: false,
          );

      if (!mounted) return;

      setState(() {
        _bookings =
            List<Map<String, dynamic>>.from(response);

        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;

        _errorMessage = e
            .toString()
            .replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  // ==========================================================================
  // DATE
  // ==========================================================================

  String _formatDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Date not available';
    }

    try {
      final DateTime date = DateTime.parse(value);

      const List<String> months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];

      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return value;
    }
  }

  // ==========================================================================
  // PRICE
  // ==========================================================================

  String _formatPrice(dynamic value) {
    final double price =
        double.tryParse(
              value?.toString() ?? '',
            ) ??
            0;

    return '₹${price.toStringAsFixed(0)}';
  }

  // ==========================================================================
  // SERVICE
  // ==========================================================================

  Map<String, dynamic>? _serviceMap(
    Map<String, dynamic> booking,
  ) {
    final dynamic service = booking['services'];

    if (service is Map) {
      return Map<String, dynamic>.from(service);
    }

    if (service is List &&
        service.isNotEmpty &&
        service.first is Map) {
      return Map<String, dynamic>.from(service.first);
    }

    return null;
  }

  String _serviceName(
    Map<String, dynamic> booking,
  ) {
    final Map<String, dynamic>? service =
        _serviceMap(booking);

    return service?['name']?.toString() ?? 'Service';
  }

  String _serviceImage(
    Map<String, dynamic> booking,
  ) {
    final Map<String, dynamic>? service =
        _serviceMap(booking);

    if (service == null) {
      return '';
    }

    final dynamic gallery = service['gallery'];

    if (gallery is List && gallery.isNotEmpty) {
      final dynamic first = gallery.first;

      if (first is String && first.trim().isNotEmpty) {
        return first;
      }
    }

    if (gallery is String && gallery.trim().isNotEmpty) {
      return gallery;
    }

    return '';
  }

  // ==========================================================================
  // VENDOR
  // ==========================================================================

  Map<String, dynamic>? _vendorMap(
    Map<String, dynamic> booking,
  ) {
    final dynamic vendor = booking['vendors'];

    if (vendor is Map) {
      return Map<String, dynamic>.from(vendor);
    }

    if (vendor is List &&
        vendor.isNotEmpty &&
        vendor.first is Map) {
      return Map<String, dynamic>.from(vendor.first);
    }

    return null;
  }

  String _vendorName(
    Map<String, dynamic> booking,
  ) {
    final Map<String, dynamic>? vendor =
        _vendorMap(booking);

    return vendor?['name']?.toString() ?? 'Vendor';
  }

  String _vendorEmail(
    Map<String, dynamic> booking,
  ) {
    final Map<String, dynamic>? vendor =
        _vendorMap(booking);

    return vendor?['email']?.toString() ?? '';
  }

  // ==========================================================================
  // EVENT TYPE
  // ==========================================================================

  String _eventType(
    Map<String, dynamic> booking,
  ) {
    final dynamic eventType =
        booking['event_types'];

    if (eventType is Map) {
      return eventType['name']?.toString() ?? '';
    }

    if (eventType is List &&
        eventType.isNotEmpty &&
        eventType.first is Map) {
      return eventType.first['name']?.toString() ?? '';
    }

    return '';
  }

  // ==========================================================================
  // STATUS
  // ==========================================================================

  String _bookingStatus(
    Map<String, dynamic> booking,
  ) {
    return booking['status']
            ?.toString()
            .toLowerCase() ??
        'pending';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;

      case 'accepted':
        return Colors.green;

      case 'confirmed':
        return Colors.green.shade700;

      case 'completed':
        return Colors.blue;

      case 'rejected':
        return Colors.red;

      case 'cancelled':
      case 'canceled':
        return Colors.grey;

      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule_rounded;

      case 'accepted':
        return Icons.check_circle_outline_rounded;

      case 'confirmed':
        return Icons.verified_rounded;

      case 'completed':
        return Icons.task_alt_rounded;

      case 'rejected':
        return Icons.cancel_outlined;

      case 'cancelled':
      case 'canceled':
        return Icons.block_rounded;

      default:
        return Icons.info_outline_rounded;
    }
  }

  String _statusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';

      case 'accepted':
        return 'Accepted';

      case 'confirmed':
        return 'Confirmed';

      case 'completed':
        return 'Completed';

      case 'rejected':
        return 'Rejected';

      case 'cancelled':
      case 'canceled':
        return 'Cancelled';

      default:
        return status;
    }
  }

  // ==========================================================================
  // FILTER
  // ==========================================================================

  List<Map<String, dynamic>> get _filteredBookings {
    if (_selectedFilter == 'All') {
      return _bookings;
    }

    return _bookings.where(
      (booking) {
        final String status =
            _bookingStatus(booking);

        switch (_selectedFilter) {
          case 'Upcoming':
            return status == 'pending' ||
                status == 'accepted' ||
                status == 'confirmed';

          case 'Completed':
            return status == 'completed';

          case 'Cancelled':
            return status == 'cancelled' ||
                status == 'canceled' ||
                status == 'rejected';

          default:
            return true;
        }
      },
    ).toList();
  }

  // ==========================================================================
  // STATISTICS
  // ==========================================================================

  int get _totalCount => _bookings.length;

  int get _upcomingCount {
    return _bookings.where(
      (booking) {
        final String status =
            _bookingStatus(booking);

        return status == 'pending' ||
            status == 'accepted' ||
            status == 'confirmed';
      },
    ).length;
  }

  int get _completedCount {
    return _bookings.where(
      (booking) =>
          _bookingStatus(booking) == 'completed',
    ).length;
  }

  int get _cancelledCount {
    return _bookings.where(
      (booking) {
        final String status =
            _bookingStatus(booking);

        return status == 'cancelled' ||
            status == 'canceled' ||
            status == 'rejected';
      },
    ).length;
  }

  // ==========================================================================
  // ACTIVE BOOKING
  // ==========================================================================

  Map<String, dynamic>? get _activeBooking {
    for (final booking in _bookings) {
      final String status =
          _bookingStatus(booking);

      if (status == 'accepted' ||
          status == 'confirmed') {
        return booking;
      }
    }

    for (final booking in _bookings) {
      if (_bookingStatus(booking) == 'pending') {
        return booking;
      }
    }

    return null;
  }

  // ==========================================================================
  // SHOW DETAILS
  // ==========================================================================

  void _showBookingDetails(
    Map<String, dynamic> booking,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _BookingDetailsSheet(
          booking: booking,
          serviceName: _serviceName(booking),
          serviceImage: _serviceImage(booking),
          vendorName: _vendorName(booking),
          vendorEmail: _vendorEmail(booking),
          eventType: _eventType(booking),
          formatDate: _formatDate,
          formatPrice: _formatPrice,
          statusColor: _statusColor,
          statusIcon: _statusIcon,
          statusText: _statusText,
        );
      },
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          EventraBookingColors.background,
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  // ==========================================================================
  // BODY
  // ==========================================================================

  Widget _buildBody() {
    if (_isLoading && _bookings.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: EventraBookingColors.primaryRed,
        ),
      );
    }

    if (_errorMessage != null &&
        _bookings.isEmpty) {
      return _buildErrorState();
    }

    if (_bookings.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: EventraBookingColors.primaryRed,
      onRefresh: _loadBookings,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(),
          ),

          SliverToBoxAdapter(
            child: _buildFilterTabs(),
          ),

          SliverToBoxAdapter(
            child: _buildStatistics(),
          ),

          if (_activeBooking != null)
            SliverToBoxAdapter(
              child: _buildActiveBooking(
                _activeBooking!,
              ),
            ),

          SliverToBoxAdapter(
            child: _buildSectionTitle(
              'Your Bookings',
              '${_filteredBookings.length} booking${_filteredBookings.length == 1 ? '' : 's'}',
            ),
          ),

          if (_filteredBookings.isEmpty)
            SliverToBoxAdapter(
              child: _buildFilteredEmpty(),
            )
          else
            SliverList(
              delegate:
                  SliverChildBuilderDelegate(
                (
                  BuildContext context,
                  int index,
                ) {
                  final Map<String, dynamic>
                      booking =
                      _filteredBookings[index];

                  return Padding(
                    padding:
                        const EdgeInsets.fromLTRB(
                      14,
                      0,
                      14,
                      12,
                    ),
                    child: _buildBookingCard(
                      booking,
                    ),
                  );
                },
                childCount:
                    _filteredBookings.length,
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(
              height: 128,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  Widget _buildHeader() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        13,
        12,
        4,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'My Bookings',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color:
                    EventraBookingColors.textDark,
              ),
            ),
          ),

          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder:
                  const CircleBorder(),
              onTap:
                  _isLoading
                      ? null
                      : _loadBookings,
              child: const SizedBox(
                width: 38,
                height: 38,
                child: Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color:
                      EventraBookingColors.textDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // FILTER TABS
  // ==========================================================================

  Widget _buildFilterTabs() {
    return SizedBox(
      height: 43,
      child: ListView.builder(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 14,
        ),
        scrollDirection: Axis.horizontal,
        physics:
            const BouncingScrollPhysics(),
        itemCount: _filters.length,
        itemBuilder:
            (
          BuildContext context,
          int index,
        ) {
          final String filter =
              _filters[index];

          final bool selected =
              _selectedFilter == filter;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter;
              });
            },
            child: AnimatedContainer(
              duration:
                  const Duration(
                milliseconds: 180,
              ),
              margin:
                  const EdgeInsets.only(
                right: 7,
                top: 5,
                bottom: 5,
              ),
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 13,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? EventraBookingColors
                        .primaryRed
                    : Colors.white,
                borderRadius:
                    BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? EventraBookingColors
                          .primaryRed
                      : Colors.grey.shade200,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                filter,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : EventraBookingColors
                          .textGrey,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================================================
  // STATISTICS
  // ==========================================================================

  Widget _buildStatistics() {
    return SizedBox(
      height: 76,
      child: ListView(
        padding:
            const EdgeInsets.fromLTRB(
          14,
          7,
          14,
          5,
        ),
        scrollDirection: Axis.horizontal,
        physics:
            const BouncingScrollPhysics(),
        children: [
          _buildStatCard(
            value: _totalCount.toString(),
            label: 'Total',
            icon:
                Icons.calendar_month_rounded,
          ),
          _buildStatCard(
            value:
                _upcomingCount.toString(),
            label: 'Upcoming',
            icon:
                Icons.event_available_rounded,
          ),
          _buildStatCard(
            value:
                _completedCount.toString(),
            label: 'Completed',
            icon:
                Icons.task_alt_rounded,
          ),
          _buildStatCard(
            value:
                _cancelledCount.toString(),
            label: 'Cancelled',
            icon:
                Icons.cancel_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String value,
    required String label,
    required IconData icon,
  }) {
    return Container(
      width: 84,
      margin:
          const EdgeInsets.only(
        right: 7,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(11),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 12,
                color:
                    EventraBookingColors
                        .primaryRed,
              ),
              const Spacer(),
              Text(
                value,
                style:
                    const TextStyle(
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      EventraBookingColors
                          .primaryRed,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            label,
            style:
                const TextStyle(
              fontSize: 8,
              color:
                  EventraBookingColors
                      .textGrey,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // ACTIVE BOOKING
  // ==========================================================================

  Widget _buildActiveBooking(
    Map<String, dynamic> booking,
  ) {
    final String status =
        _bookingStatus(booking);

    final String service =
        _serviceName(booking);

    final String event =
        _eventType(booking);

    final String date =
        _formatDate(
      booking['event_date']?.toString(),
    );

    final String location =
        booking['location']?.toString() ?? '';

    final int progress =
        _progressValue(status);

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        14,
        7,
        14,
        5,
      ),
      child: GestureDetector(
        onTap: () {
          _showBookingDetails(
            booking,
          );
        },
        child: Container(
          height: 160,
          decoration:
              BoxDecoration(
            gradient:
                const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF650000),
                Color(0xFF9F0101),
              ],
            ),
            borderRadius:
                BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color:
                    EventraBookingColors
                        .primaryRed
                        .withValues(
                  alpha: 0.20,
                ),
                blurRadius: 12,
                offset:
                    const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -35,
                child: Container(
                  width: 105,
                  height: 105,
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.white
                            .withValues(
                      alpha: 0.07,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              Positioned(
                right: 18,
                bottom: -35,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.white
                            .withValues(
                      alpha: 0.08,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  14,
                  13,
                  14,
                  12,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Active Booking',
                            style:
                                TextStyle(
                              color:
                                  Colors.white70,
                              fontSize: 8,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),
                        _whiteStatusBadge(
                          status,
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Text(
                      event.isEmpty
                          ? service
                          : event,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      service,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        color:
                            Colors.white70,
                        fontSize: 9,
                      ),
                    ),

                    const Spacer(),

                    Row(
                      children: [
                        const Icon(
                          Icons
                              .calendar_today_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(
                          width: 4,
                        ),
                        Expanded(
                          child: Text(
                            date,
                            style:
                                const TextStyle(
                              color:
                                  Colors.white,
                              fontSize: 8.5,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),
                        if (location.isNotEmpty)
                          Row(
                            children: [
                              const Icon(
                                Icons
                                    .location_on_rounded,
                                size: 12,
                                color:
                                    Colors.white,
                              ),
                              const SizedBox(
                                width: 3,
                              ),
                              SizedBox(
                                width: 90,
                                child: Text(
                                  location,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    color:
                                        Colors.white,
                                    fontSize: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),

                    const SizedBox(
                      height: 9,
                    ),

                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                      child:
                          LinearProgressIndicator(
                        value:
                            progress / 100,
                        minHeight: 4,
                        backgroundColor:
                            Colors.white
                                .withValues(
                          alpha: 0.18,
                        ),
                        valueColor:
                            const AlwaysStoppedAnimation<
                                Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(
                right: 13,
                top: 35,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration:
                      BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$progress%',
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _whiteStatusBadge(
    String status,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white.withValues(
          alpha: 0.13,
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            _statusIcon(status),
            size: 10,
            color: Colors.white,
          ),
          const SizedBox(
            width: 3,
          ),
          Text(
            _statusText(status),
            style:
                const TextStyle(
              color: Colors.white,
              fontSize: 7.5,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  int _progressValue(
    String status,
  ) {
    switch (status) {
      case 'pending':
        return 25;

      case 'accepted':
        return 65;

      case 'confirmed':
        return 85;

      case 'completed':
        return 100;

      default:
        return 10;
    }
  }

  // ==========================================================================
  // SECTION TITLE
  // ==========================================================================

  Widget _buildSectionTitle(
    String title,
    String trailing,
  ) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        14,
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
                fontSize: 14,
                fontWeight:
                    FontWeight.w800,
                color:
                    EventraBookingColors
                        .textDark,
              ),
            ),
          ),
          Text(
            trailing,
            style:
                const TextStyle(
              fontSize: 8,
              color:
                  EventraBookingColors
                      .primaryRed,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // BOOKING CARD
  // ==========================================================================

  Widget _buildBookingCard(
    Map<String, dynamic> booking,
  ) {
    final String status =
        _bookingStatus(booking);

    final Color color =
        _statusColor(status);

    final String service =
        _serviceName(booking);

    final String vendor =
        _vendorName(booking);

    final String event =
        _eventType(booking);

    final String date =
        _formatDate(
      booking['event_date']?.toString(),
    );

    final String location =
        booking['location']?.toString() ?? '';

    final String image =
        _serviceImage(booking);

    return GestureDetector(
      onTap: () {
        _showBookingDetails(
          booking,
        );
      },
      child: Container(
        padding:
            const EdgeInsets.all(9),
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(15),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(
                alpha: 0.035,
              ),
              blurRadius: 8,
              offset:
                  const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildBookingImage(image),

            const SizedBox(
              width: 10,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          service,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              const TextStyle(
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w800,
                            color:
                                EventraBookingColors
                                    .textDark,
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 5,
                      ),

                      _buildStatusBadge(
                        status,
                        color,
                      ),
                    ],
                  ),

                  if (event.isNotEmpty) ...[
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      event,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 8,
                        color:
                            EventraBookingColors
                                .primaryRed,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],

                  const SizedBox(
                    height: 6,
                  ),

                  _smallInfoRow(
                    Icons.storefront_outlined,
                    vendor,
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  _smallInfoRow(
                    Icons.calendar_today_outlined,
                    date,
                  ),

                  if (location.isNotEmpty) ...[
                    const SizedBox(
                      height: 4,
                    ),
                    _smallInfoRow(
                      Icons.location_on_outlined,
                      location,
                    ),
                  ],

                  const SizedBox(
                    height: 7,
                  ),

                  Row(
                    children: [
                      Text(
                        _formatPrice(
                          booking['price'],
                        ),
                        style:
                            const TextStyle(
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w800,
                          color:
                              EventraBookingColors
                                  .textDark,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons
                            .arrow_forward_ios_rounded,
                        size: 11,
                        color:
                            EventraBookingColors
                                .primaryRed,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallInfoRow(
    IconData icon,
    String text,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 11,
          color:
              EventraBookingColors.textGrey,
        ),
        const SizedBox(
          width: 4,
        ),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style:
                const TextStyle(
              fontSize: 8,
              color:
                  EventraBookingColors
                      .textGrey,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookingImage(
    String image,
  ) {
    if (image.isEmpty) {
      return Container(
        width: 70,
        height: 82,
        decoration:
            BoxDecoration(
          color:
              EventraBookingColors.lightRed,
          borderRadius:
              BorderRadius.circular(11),
        ),
        child: const Icon(
          Icons
              .miscellaneous_services_rounded,
          size: 27,
          color:
              EventraBookingColors.primaryRed,
        ),
      );
    }

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(11),
      child: Image.network(
        image,
        width: 70,
        height: 82,
        fit: BoxFit.cover,
        errorBuilder:
            (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return Container(
            width: 70,
            height: 82,
            color:
                EventraBookingColors.lightRed,
            child: const Icon(
              Icons
                  .miscellaneous_services_rounded,
              size: 27,
              color:
                  EventraBookingColors
                      .primaryRed,
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(
    String status,
    Color color,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration:
          BoxDecoration(
        color:
            color.withValues(alpha: 0.10),
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            _statusIcon(status),
            size: 9,
            color: color,
          ),
          const SizedBox(
            width: 3,
          ),
          Text(
            _statusText(status),
            style:
                TextStyle(
              fontSize: 6.5,
              fontWeight:
                  FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // FILTER EMPTY
  // ==========================================================================

  Widget _buildFilteredEmpty() {
    return Padding(
      padding:
          const EdgeInsets.all(35),
      child: Column(
        children: [
          Container(
            width: 65,
            height: 65,
            decoration:
                const BoxDecoration(
              color:
                  EventraBookingColors
                      .lightRed,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_busy_rounded,
              color:
                  EventraBookingColors
                      .primaryRed,
              size: 30,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          const Text(
            'No bookings here',
            style:
                TextStyle(
              fontSize: 15,
              fontWeight:
                  FontWeight.w700,
              color:
                  EventraBookingColors
                      .textDark,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            'You don\'t have any $_selectedFilter bookings.',
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              fontSize: 9,
              color:
                  EventraBookingColors
                      .textGrey,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // EMPTY
  // ==========================================================================

  Widget _buildEmptyState() {
    return RefreshIndicator(
      color:
          EventraBookingColors.primaryRed,
      onRefresh: _loadBookings,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height:
                MediaQuery.of(context)
                        .size
                        .height *
                    0.22,
          ),

          Center(
            child: Container(
              width: 82,
              height: 82,
              decoration:
                  const BoxDecoration(
                color:
                    EventraBookingColors
                        .lightRed,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons
                    .calendar_month_rounded,
                size: 40,
                color:
                    EventraBookingColors
                        .primaryRed,
              ),
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          const Center(
            child: Text(
              'No Bookings Yet',
              style:
                  TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.w800,
                color:
                    EventraBookingColors
                        .textDark,
              ),
            ),
          ),

          const SizedBox(
            height: 7,
          ),

          const Padding(
            padding:
                EdgeInsets.symmetric(
              horizontal: 50,
            ),
            child: Text(
              'Your booked services will appear here once you start planning your event.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 11,
                color:
                    EventraBookingColors
                        .textGrey,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // ERROR
  // ==========================================================================

  Widget _buildErrorState() {
    return RefreshIndicator(
      color:
          EventraBookingColors.primaryRed,
      onRefresh: _loadBookings,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height:
                MediaQuery.of(context)
                        .size
                        .height *
                    0.20,
          ),

          const Center(
            child: Icon(
              Icons.cloud_off_rounded,
              size: 58,
              color:
                  EventraBookingColors
                      .primaryRed,
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          const Center(
            child: Text(
              'Unable to Load Bookings',
              style:
                  TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.w800,
                color:
                    EventraBookingColors
                        .textDark,
              ),
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 30,
            ),
            child: Text(
              _errorMessage ??
                  'Something went wrong.',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontSize: 10,
                color:
                    EventraBookingColors
                        .textGrey,
              ),
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          Center(
            child: ElevatedButton.icon(
              onPressed:
                  _loadBookings,
              icon:
                  const Icon(
                Icons.refresh_rounded,
                size: 16,
              ),
              label:
                  const Text(
                'Try Again',
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    EventraBookingColors
                        .primaryRed,
                foregroundColor:
                    Colors.white,
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BOOKING DETAILS SHEET
// ============================================================================

class _BookingDetailsSheet
    extends StatelessWidget {
  final Map<String, dynamic> booking;

  final String serviceName;
  final String serviceImage;
  final String vendorName;
  final String vendorEmail;
  final String eventType;

  final String Function(String?) formatDate;
  final String Function(dynamic) formatPrice;
  final Color Function(String) statusColor;
  final IconData Function(String) statusIcon;
  final String Function(String) statusText;

  const _BookingDetailsSheet({
    required this.booking,
    required this.serviceName,
    required this.serviceImage,
    required this.vendorName,
    required this.vendorEmail,
    required this.eventType,
    required this.formatDate,
    required this.formatPrice,
    required this.statusColor,
    required this.statusIcon,
    required this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    final String status =
        booking['status']
                ?.toString()
                .toLowerCase() ??
            'pending';

    final Color color =
        statusColor(status);

    final String date =
        formatDate(
      booking['event_date']?.toString(),
    );

    final String location =
        booking['location']?.toString() ?? '';

    final String requirement =
        booking['requirement']?.toString() ?? '';

    final dynamic guests =
        booking['guest_count'];

    return Container(
      height:
          MediaQuery.of(context)
                  .size
                  .height *
              0.82,
      decoration:
          const BoxDecoration(
        color:
            EventraBookingColors.background,
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(
            height: 9,
          ),

          Container(
            width: 42,
            height: 4,
            decoration:
                BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius:
                  BorderRadius.circular(10),
            ),
          ),

          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              13,
              8,
              8,
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Booking Details',
                    style:
                        TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w800,
                      color:
                          EventraBookingColors
                              .textDark,
                    ),
                  ),
                ),

                IconButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                    );
                  },
                  icon:
                      const Icon(
                    Icons.close_rounded,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              physics:
                  const BouncingScrollPhysics(),
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                0,
                16,
                30,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // ==========================================================
                  // SERVICE
                  // ==========================================================

                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(
                      12,
                    ),
                    decoration:
                        BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildServiceImage(),

                        const SizedBox(
                          width: 12,
                        ),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                serviceName,
                                maxLines: 2,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style:
                                    const TextStyle(
                                  fontSize: 15,
                                  fontWeight:
                                      FontWeight.w800,
                                  color:
                                      EventraBookingColors
                                          .textDark,
                                ),
                              ),

                              if (eventType
                                  .isNotEmpty) ...[
                                const SizedBox(
                                  height: 4,
                                ),
                                Text(
                                  eventType,
                                  style:
                                      const TextStyle(
                                    fontSize: 9,
                                    color:
                                        EventraBookingColors
                                            .primaryRed,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                              ],

                              const SizedBox(
                                height: 7,
                              ),

                              Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration:
                                    BoxDecoration(
                                  color:
                                      color.withValues(
                                    alpha: 0.10,
                                  ),
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    20,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize:
                                      MainAxisSize.min,
                                  children: [
                                    Icon(
                                      statusIcon(
                                        status,
                                      ),
                                      size: 12,
                                      color:
                                          color,
                                    ),
                                    const SizedBox(
                                      width: 4,
                                    ),
                                    Text(
                                      statusText(
                                        status,
                                      ),
                                      style:
                                          TextStyle(
                                        fontSize: 8,
                                        fontWeight:
                                            FontWeight
                                                .w700,
                                        color:
                                            color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  _buildProgress(status),

                  const SizedBox(
                    height: 12,
                  ),

                  // ==========================================================
                  // EVENT
                  // ==========================================================

                  _buildSection(
                    title: 'Event Details',
                    child: Column(
                      children: [
                        _detailRow(
                          Icons
                              .calendar_today_rounded,
                          'Event Date',
                          date,
                        ),
                        if (guests != null)
                          _detailRow(
                            Icons.groups_rounded,
                            'Guests',
                            guests.toString(),
                          ),
                        _detailRow(
                          Icons
                              .location_on_rounded,
                          'Location',
                          location.isEmpty
                              ? 'Not specified'
                              : location,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  // ==========================================================
                  // VENDOR
                  // ==========================================================

                  _buildSection(
                    title: 'Vendor',
                    child: Column(
                      children: [
                        _detailRow(
                          Icons
                              .storefront_rounded,
                          'Vendor',
                          vendorName,
                        ),
                        if (vendorEmail.isNotEmpty)
                          _detailRow(
                            Icons.email_outlined,
                            'Email',
                            vendorEmail,
                          ),
                      ],
                    ),
                  ),

                  if (requirement.trim().isNotEmpty) ...[
                    const SizedBox(
                      height: 12,
                    ),
                    _buildSection(
                      title: 'Requirement',
                      child: Align(
                        alignment:
                            Alignment.centerLeft,
                        child: Text(
                          requirement,
                          style:
                              const TextStyle(
                            fontSize: 10,
                            color:
                                EventraBookingColors
                                    .textGrey,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(
                    height: 12,
                  ),

                  // ==========================================================
                  // PRICE
                  // ==========================================================

                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(
                      14,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          EventraBookingColors
                              .primaryRed,
                      borderRadius:
                          BorderRadius.circular(
                        15,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Booking Total',
                            style:
                                TextStyle(
                              color:
                                  Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        Text(
                          formatPrice(
                            booking['price'],
                          ),
                          style:
                              const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SECTION
  // ==========================================================================

  Widget _buildSection({
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(14),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:
                const TextStyle(
              fontSize: 13,
              fontWeight:
                  FontWeight.w800,
              color:
                  EventraBookingColors
                      .textDark,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          child,
        ],
      ),
    );
  }

  // ==========================================================================
  // DETAIL ROW
  // ==========================================================================

  Widget _detailRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 9,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 29,
            height: 29,
            decoration:
                const BoxDecoration(
              color:
                  EventraBookingColors
                      .lightRed,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 14,
              color:
                  EventraBookingColors
                      .primaryRed,
            ),
          ),

          const SizedBox(
            width: 9,
          ),

          SizedBox(
            width: 75,
            child: Text(
              title,
              style:
                  const TextStyle(
                fontSize: 9,
                color:
                    EventraBookingColors
                        .textGrey,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value,
              textAlign:
                  TextAlign.right,
              style:
                  const TextStyle(
                fontSize: 9,
                fontWeight:
                    FontWeight.w700,
                color:
                    EventraBookingColors
                        .textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PROGRESS
  // ==========================================================================

  Widget _buildProgress(
    String status,
  ) {
    final int current =
        _progressStep(status);

    const List<String> steps = [
      'Requested',
      'Accepted',
      'Confirmed',
      'Completed',
    ];

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(14),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Booking Progress',
            style:
                TextStyle(
              fontSize: 13,
              fontWeight:
                  FontWeight.w800,
              color:
                  EventraBookingColors
                      .textDark,
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          Row(
            children: List.generate(
              steps.length,
              (index) {
                final bool done =
                    index <= current;

                return Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 13,
                        height: 13,
                        decoration:
                            BoxDecoration(
                          color: done
                              ? EventraBookingColors
                                  .primaryRed
                              : Colors
                                  .grey
                                  .shade200,
                          shape:
                              BoxShape.circle,
                        ),
                      ),

                      if (index <
                          steps.length - 1)
                        Expanded(
                          child:
                              Container(
                            height: 2,
                            color: index <
                                    current
                                ? EventraBookingColors
                                    .primaryRed
                                : Colors
                                    .grey
                                    .shade200,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(
            height: 7,
          ),

          Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
            children: steps
                .map(
                  (String step) {
                    return Text(
                      step,
                      style:
                          const TextStyle(
                        fontSize: 6.5,
                        color:
                            EventraBookingColors
                                .textGrey,
                      ),
                    );
                  },
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  int _progressStep(
    String status,
  ) {
    switch (status) {
      case 'pending':
        return 0;

      case 'accepted':
        return 1;

      case 'confirmed':
        return 2;

      case 'completed':
        return 3;

      default:
        return 0;
    }
  }

  // ==========================================================================
  // SERVICE IMAGE
  // ==========================================================================

  Widget _buildServiceImage() {
    if (serviceImage.isEmpty) {
      return Container(
        width: 72,
        height: 72,
        decoration:
            BoxDecoration(
          color:
              EventraBookingColors
                  .lightRed,
          borderRadius:
              BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons
              .miscellaneous_services_rounded,
          color:
              EventraBookingColors
                  .primaryRed,
          size: 28,
        ),
      );
    }

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(12),
      child: Image.network(
        serviceImage,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder:
            (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) {
          return Container(
            width: 72,
            height: 72,
            color:
                EventraBookingColors
                    .lightRed,
            child: const Icon(
              Icons
                  .miscellaneous_services_rounded,
              color:
                  EventraBookingColors
                      .primaryRed,
              size: 28,
            ),
          );
        },
      ),
    );
  }
}