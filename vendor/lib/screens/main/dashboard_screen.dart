import 'package:eventor_vendor/services/app_settings_controller.dart';

import '../../widgets/reviews/recent_review_card.dart';
import '../../models/service_review_model.dart';
import '../../widgets/bookings/vendor_booking_card.dart';
import '../../widgets/trial/vendor_setup_checklist.dart';

import 'package:eventor_vendor/core/theme/app_icon_colors.dart';

import '../../services/app_live_data.dart';
import '../../widgets/vendor_filter_button.dart';
import '../../widgets/listings/listing_filter_sheet.dart';
import '../../widgets/common/app_shimmer.dart';

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/vendor_notifications_repository.dart';
import '../extended/notifications_screen.dart';

import 'package:flutter/material.dart';

import '../../models/booking_model.dart';
import '../../models/calendar_bookings.dart';
import '../../models/dashboard_data.dart';
import '../../repositories/dashboard_repository.dart';
import '../extended/booking_details_screen.dart';
import '../../widgets/bookings/booking_ui.dart';
import '../extended/listing_editor_screen.dart';
import '../extended/service_reviews_screen.dart';
import '../../models/business_model.dart';

import '../../repositories/booking_repository.dart';

import '../extended/business_details.dart';
import '../extended/eventor_calendar.dart';

import 'bookings_screen.dart';

class DashboardScreen extends StatefulWidget {
  final DashboardRepository? repository;
  final BookingRepository? bookingRepository;
  final bool isActive;
  final ValueChanged<int>? onNavigate;
  const DashboardScreen({
    super.key,
    this.repository,
    this.bookingRepository,
    this.isActive = true,
    this.onNavigate,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver, LiveDataState<DashboardScreen> {
  @override
  Set<String> get liveDatasets => {
    'own:vendors',
    'own:businesses',
    'own:services',
    'own:bookings',
    'own:service_reviews',
    'own:service_metrics',
    'own:vendor_notifications',
    'own:vendor_announcements',
    'public:vendor_announcements',
  };
  @override
  Future<void> onLiveData(Set<String> changed) async {
    if (changed.any(
      (d) =>
          d.contains('vendor_notifications') ||
          d.contains('vendor_announcements'),
    )) {
      await _refreshInbox();
    }
    if (changed.any(
      (d) =>
          !d.contains('vendor_notifications') &&
          !d.contains('vendor_announcements'),
    )) {
      if (changed.contains('own:businesses') &&
          _selectedBusiness != 'all' &&
          _selectedBusiness != 'unassigned') {
        final businesses = await _repository.businesses();
        if (!mounted) return;
        if (!businesses.any((b) => b.id == _selectedBusiness)) {
          setState(() => _selectedBusiness = 'all');
        }
      }
      await _loadDashboard();
    }
  }

  late final VendorNotificationsRepository _inbox;
  RealtimeChannel? _inboxChannel;
  Timer? _inboxTimer;
  int _unreadNotifications = 0;
  bool _loadingInbox = false;
  // ============================================================
  // COLORS
  // ============================================================

  static const Color primaryRed = Color(0xFF80152C);
  static const Color wineDark = Color(0xFF650C20);
  static const Color darkText = Color(0xFF17171B);
  static const Color greyText = Color(0xFF73737D);
  static const Color background = Color(0xFFF8F8FA);
  static const Color lightRed = Color(0xFFF5E8EC);
  static const Color gold = Color(0xFFFFCB48);

  // ============================================================
  // REPOSITORIES
  // ============================================================

  late final DashboardRepository _repository;
  DashboardOverview? _overview;
  String _selectedBusiness = 'all';
  String _bookingSort = 'newest';
  int _generation = 0;
  final Set<String> _busyIds = {};
  List<BusinessModel> _allBusinesses = [];
  List<BookingModel> _allBookings = [];

  String _vendorName = 'Vendor';
  String? _profileImageUrl;

  List<BusinessModel> get _businesses => _allBusinesses
      .where(
        (b) =>
            _selectedBusiness == 'all' ? b.isActive : b.id == _selectedBusiness,
      )
      .toList();

  List<BookingModel> get _bookings =>
      calendarScope(_allBookings, business: _selectedBusiness);

  bool _isLoading = true;
  String? _errorMessage;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? DashboardRepository();
    _loadDashboard();
    WidgetsBinding.instance.addObserver(this);
    _inbox = VendorNotificationsRepository();
    _inboxChannel = _inbox.watch(_scheduleInbox);
    _inboxTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _scheduleInbox(),
    );
    _refreshInbox();
  }

  void _scheduleInbox() {
    AppLiveData.instance.invalidate({'own:vendor_notifications'});
  }

  Future<void> _refreshInbox() async {
    if (_loadingInbox || !mounted) return;
    _loadingInbox = true;
    try {
      await _inbox.syncAnnouncements();
      final count = await _inbox.unreadCount();
      if (mounted) setState(() => _unreadNotifications = count);
    } catch (_) {
      // Retain the last confirmed unread count during a connection failure.
    } finally {
      _loadingInbox = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scheduleInbox();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inboxTimer?.cancel();
    if (_inboxChannel != null) unawaited(_inbox.stopWatching(_inboxChannel!));
    super.dispose();
  }

  // ============================================================
  // LOAD DASHBOARD
  // ============================================================

  Future<void> _loadDashboard() async {
    if (!mounted) return;
    final generation = ++_generation;
    setState(() {
      _isLoading = _overview == null;
      _errorMessage = null;
    });
    try {
      final fresh = await _repository.load(business: _selectedBusiness);
      if (!mounted || generation != _generation) return;
      setState(() {
        _vendorName = fresh.vendor?.name ?? 'Vendor';
        _profileImageUrl = fresh.vendor?.profileImageUrl;
        _allBusinesses = fresh.businesses;
        _allBookings = fresh.bookings;
        _overview = fresh.overview;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _isLoading = false;
        _errorMessage = _cleanError(e);
      });
    }
  }

  String _cleanError(Object error) {
    final String message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring(11);
    }

    return message;
  }

  // ============================================================
  // BOOKING COUNTS
  // ============================================================

  int _countStatus(String status) {
    return _bookings
        .where(
          (BookingModel booking) =>
              booking.status.toLowerCase() == status.toLowerCase(),
        )
        .length;
  }

  int get _pendingBookings => _countStatus('pending');
  int get _acceptedBookings => _countStatus('accepted');
  int get _completedBookings => _countStatus('completed');
  int get _cancelledBookings => _countStatus('cancelled');

  // ============================================================
  // ACTIVE SERVICES
  // ============================================================

  int get _activeServices => _overview?.activeServices ?? 0;

  List<BookingModel> get _recentBookings {
    final List<BookingModel> list = List<BookingModel>.from(_bookings);

    list.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final result = switch (_bookingSort) {
        'oldest' => aDate.compareTo(bDate),
        'event_date' => (a.eventDate ?? DateTime(9999)).compareTo(
          b.eventDate ?? DateTime(9999),
        ),
        'price_low' => a.price.compareTo(b.price),
        'price_high' => b.price.compareTo(a.price),
        _ => bDate.compareTo(aDate),
      };
      return result == 0 ? a.id.compareTo(b.id) : result;
    });

    return list.take(5).toList();
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refresh() async {
    await _loadDashboard();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: AppShimmerRefreshIndicator(
          onRefresh: _refresh,
          color: primaryRed,
          child: _buildBody(),
        ),
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: AppContentSkeleton(layout: SkeletonLayout.dashboard),
      );
    }

    if (_errorMessage != null && _overview == null) {
      return _buildErrorState();
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage != null) ...[
            MaterialBanner(
              content: Text(
                AppSettingsScope.translate(
                  context,
                  "vendor.unable_to_refresh_showing_saved_dashboard_dat.1355f36e",
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _loadDashboard,
                  child: Text(
                    AppSettingsScope.translate(
                      context,
                      "vendor.retry.942087cc",
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          _buildHeader(),
          const SizedBox(height: 24),
          const VendorSetupChecklistCard(),
          _buildStats(),
          const SizedBox(height: 18),
          _buildBookingOverview(),
          const SizedBox(height: 28),
          _buildSectionHeader(
            title: AppSettingsScope.translate(
              context,
              "vendor.quick_actions.2cc2b6f7",
            ),
          ),
          const SizedBox(height: 12),
          _buildQuickActions(),
          const SizedBox(height: 28),
          _buildSectionHeader(
            title: AppSettingsScope.translate(
              context,
              "vendor.my_businesses.126e368c",
            ),
            showAction: _businesses.isNotEmpty,
            actionText: 'See All',
            onAction: _openBusinesses,
          ),
          const SizedBox(height: 12),
          _buildBusinesses(),
          const SizedBox(height: 28),
          _buildSectionHeader(
            title: AppSettingsScope.translate(
              context,
              "vendor.recent_booking_requests.455116f3",
            ),
            showAction: _bookings.isNotEmpty,
            actionText: 'See All',
            onAction: _openBookings,
          ),
          const SizedBox(height: 12),
          _buildRecentBookings(),
          ..._buildUpgradeSections(),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    final String name = _vendorName.trim();
    final List<String> parts = name.split(RegExp(r'\s+'));

    final String firstName = parts.isEmpty || parts.first.isEmpty
        ? 'Vendor'
        : parts.first;

    return Row(
      children: [
        _buildProfileAvatar(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateTime.now().hour < 12
                    ? AppSettingsScope.translate(
                        context,
                        "vendor.good_morning.dd5f018b",
                      )
                    : DateTime.now().hour < 17
                    ? AppSettingsScope.translate(
                        context,
                        "vendor.good_afternoon.ff60c405",
                      )
                    : AppSettingsScope.translate(
                        context,
                        "vendor.good_evening.ae140162",
                      ),
                style: TextStyle(fontSize: 14, color: greyText),
              ),
              const SizedBox(height: 4),
              Text(
                firstName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: darkText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        VendorFilterButton(
          tooltip: AppSettingsScope.translate(
            context,
            "vendor.filter_sort.8d76c3b1",
          ),
          onPressed: _chooseBusiness,
          active: _selectedBusiness != 'all' || _bookingSort != 'newest',
        ),
        IconButton(
          tooltip: AppSettingsScope.translate(
            context,
            "vendor.activity_alerts.9cb32fb9",
          ),
          onPressed: _showAlerts,
          icon: Badge.count(
            count: _unreadNotifications,
            isLabelVisible: _unreadNotifications > 0,
            child: const Icon(
              Icons.notifications_outlined,
              color: AppIconColors.standard,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PROFILE AVATAR
  // ============================================================

  Widget _buildProfileAvatar() {
    final String imageUrl = _profileImageUrl?.trim() ?? '';
    final bool hasImage = imageUrl.isNotEmpty;
    final String name = _vendorName.trim();

    final String initial = name.isEmpty
        ? 'V'
        : name.substring(0, 1).toUpperCase();

    return SizedBox(
      width: 52,
      height: 52,
      child: ClipOval(
        child: hasImage
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) =>
                    _buildInitialAvatar(initial),
              )
            : _buildInitialAvatar(initial),
      ),
    );
  }

  Widget _buildInitialAvatar(String initial) {
    return ColoredBox(
      color: lightRed,
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: primaryRed,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // STAT CARDS
  // ============================================================

  Widget _buildStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.storefront_outlined,
            title: AppSettingsScope.translate(
              context,
              "vendor.my_businesses.126e368c",
            ),
            value: _businesses.length.toString(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.miscellaneous_services_outlined,
            title: AppSettingsScope.translate(
              context,
              "vendor.active_services.efed7326",
            ),
            value: _activeServices.toString(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0EDF0)),
        boxShadow: [
          BoxShadow(
            color: primaryRed.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: AppIconColors.standard, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: darkText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: greyText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOOKING OVERVIEW
  // ============================================================

  Widget _buildBookingOverview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryRed, wineDark],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryRed.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppSettingsScope.translate(
                    context,
                    "vendor.booking_overview.1b70a5d6",
                  ),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  AppSettingsScope.translate(
                    context,
                    "vendor.value0_total.1c384e00",
                    args: {"value0": _bookings.length},
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildBookingStat(
                  label: AppSettingsScope.translate(
                    context,
                    "vendor.pending.331551b0",
                  ),
                  value: _pendingBookings,
                ),
              ),
              Expanded(
                child: _buildBookingStat(
                  label: AppSettingsScope.translate(
                    context,
                    "vendor.accepted.a00fb0c5",
                  ),
                  value: _acceptedBookings,
                ),
              ),
              Expanded(
                child: _buildBookingStat(
                  label: AppSettingsScope.translate(
                    context,
                    "vendor.completed.22a970d2",
                  ),
                  value: _completedBookings,
                ),
              ),
              Expanded(
                child: _buildBookingStat(
                  label: AppSettingsScope.translate(
                    context,
                    "vendor.cancelled.d353a99e",
                  ),
                  value: _cancelledBookings,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: Colors.white.withValues(alpha: 0.16), height: 1),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_overview?.upcoming ?? 0} ${AppSettingsScope.translate(context, "vendor.upcoming_events.deac9e2b")}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if ((_overview?.rejected ?? 0) > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_overview?.rejected ?? 0} ${AppSettingsScope.translate(context, "vendor.rejected.20cd938a")}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              InkWell(
                onTap: _openReviews,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _overview?.rating.count == 0
                        ? AppSettingsScope.translate(
                            context,
                            "vendor.no_reviews_yet.8b670b7e",
                          )
                        : '★ ${_overview?.rating.average?.toStringAsFixed(1)} · ${_overview?.rating.count} ${AppSettingsScope.translate(context, "vendor.reviews.54641051")}',
                    style: const TextStyle(
                      color: gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookingStat({required String label, required int value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }

  // ============================================================
  // SECTION HEADER
  // ============================================================

  Widget _buildSectionHeader({
    required String title,
    bool showAction = false,
    String actionText = 'See All',
    VoidCallback? onAction,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: darkText,
            ),
          ),
        ),
        if (showAction)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: primaryRed,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionText,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // QUICK ACTIONS
  // ============================================================

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickAction(
            icon: Icons.add_business_outlined,
            title: AppSettingsScope.translate(
              context,
              "vendor.add_business.af9cb72a",
            ),
            onTap: _openAddBusiness,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickAction(
            icon: Icons.add_box_outlined,
            title: AppSettingsScope.translate(
              context,
              "vendor.add_service.62e79d2a",
            ),
            onTap: _openListings,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickAction(
            icon: Icons.calendar_month_outlined,
            title: AppSettingsScope.translate(
              context,
              "vendor.calendar.d5d0a30b",
            ),
            onTap: _openCalendar,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickAction(
            icon: Icons.receipt_long_outlined,
            title: AppSettingsScope.translate(
              context,
              "vendor.bookings.4e5f81ad",
            ),
            onTap: _openBookings,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      shadowColor: primaryRed.withValues(alpha: 0.06),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 104),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF0EDF0)),
            boxShadow: [
              BoxShadow(
                color: primaryRed.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: Icon(icon, color: AppIconColors.standard, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: darkText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // ============================================================
  // BUSINESSES
  // ============================================================

  Widget _buildBusinesses() {
    if (_businesses.isEmpty) {
      return _buildEmptyCard(
        icon: Icons.storefront_outlined,
        title: AppSettingsScope.translate(
          context,
          "vendor.no_businesses_yet.c0adaaf0",
        ),
        subtitle: AppSettingsScope.translate(
          context,
          "vendor.add_your_first_business_to_start_creating_ser.6da6e539",
        ),
        buttonText: AppSettingsScope.translate(
          context,
          "vendor.add_business.af9cb72a",
        ),
        onPressed: _openAddBusiness,
      );
    }

    final List<BusinessModel> visibleBusinesses = _businesses.take(3).toList();

    final cardSize = MediaQuery.textScalerOf(context).scale(14) > 21
        ? 220.0
        : 180.0;
    return SizedBox(
      height: cardSize,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        primary: false,
        padding: EdgeInsets.zero,
        itemCount: visibleBusinesses.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) => SizedBox(
          width: cardSize,
          child: _buildBusinessCard(visibleBusinesses[index]),
        ),
      ),
    );
  }

  Widget _buildBusinessCard(BusinessModel business) {
    final logoUrl = business.logoUrl?.trim() ?? '';
    final address = business.address?.trim() ?? '';
    const placeholder = Icon(
      Icons.storefront_outlined,
      color: AppIconColors.standard,
      size: 32,
    );
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFF0EDF0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openBusiness(business),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: logoUrl.isEmpty
                      ? const Center(child: placeholder)
                      : Image.network(
                          logoUrl,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) =>
                              const Center(child: placeholder),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                business.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: darkText,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 13,
                    color: AppIconColors.standard,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      address.isEmpty ? 'Business location not added' : address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: greyText),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppIconColors.standard,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RECENT BOOKINGS
  // ============================================================

  Widget _buildRecentReviews() {
    final reviews = List<ServiceReviewModel>.of(_overview?.recentReviews ?? [])
      ..sort((a, b) {
        final byDate = b.createdAt.compareTo(a.createdAt);
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });
    final recent = reviews.take(5).toList();
    final side = MediaQuery.textScalerOf(context).scale(12) > 18
        ? 220.0
        : 180.0;
    return SizedBox(
      height: side,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        primary: false,
        padding: EdgeInsets.zero,
        itemCount: recent.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) => SizedBox(
          width: side,
          child: RecentReviewCard(
            review: recent[index],
            onOpen: () => _openReviews(serviceId: recent[index].serviceId),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentBookings() {
    final List<BookingModel> bookings = _recentBookings;

    if (bookings.isEmpty) {
      return _buildEmptyCard(
        icon: Icons.event_available_outlined,
        title: AppSettingsScope.translate(
          context,
          "vendor.no_booking_requests_yet.cf042c05",
        ),
        subtitle: AppSettingsScope.translate(
          context,
          "vendor.customer_booking_requests_will_appear_here.031b956f",
        ),
        buttonText: AppSettingsScope.translate(
          context,
          "vendor.view_bookings.e578b0f8",
        ),
        onPressed: _openBookings,
      );
    }

    return Column(
      children: bookings.map((BookingModel booking) {
        return _buildBookingCard(booking);
      }).toList(),
    );
  }

  // ============================================================
  // BOOKING CARD
  // ============================================================

  Widget _buildBookingCard(BookingModel booking) => VendorBookingCard(
    booking: booking,
    busy: _busyIds.contains(booking.id),
    onOpen: () => _showBooking(booking),
    onAccept: () => _changeBooking(booking, 'accepted'),
    onReject: () => _changeBooking(booking, 'rejected'),
    onComplete: () => _changeBooking(booking, 'completed'),
  );

  // ============================================================
  // STATUS BADGE
  // ============================================================

  // ============================================================
  // EMPTY CARD
  // ============================================================

  Widget _buildEmptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0EDF0)),
        boxShadow: [
          BoxShadow(
            color: primaryRed.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: Icon(icon, size: 30, color: AppIconColors.standard),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: darkText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: greyText),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 60,
              color: AppIconColors.standard,
            ),
            const SizedBox(height: 16),
            Text(
              AppSettingsScope.translate(
                context,
                "vendor.unable_to_load_dashboard.e44f7d30",
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: darkText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: greyText),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadDashboard,
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppIconColors.standard,
              ),
              label: Text(
                AppSettingsScope.translate(
                  context,
                  "vendor.try_again.df0fe9e0",
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryRed,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // OPEN ADD BUSINESS
  // ============================================================

  Future<void> _openAddBusiness() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddBusinessScreen()),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboard();
  }

  // ============================================================
  // OPEN BUSINESS
  // ============================================================

  Future<void> _openBusiness(BusinessModel business) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessSingleDetailsScreen(business: business),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboard();
  }

  // ============================================================
  // OPEN BUSINESSES
  // ============================================================

  Future<void> _openBusinesses() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const BusinessDetailsScreen()),
    );
    if (mounted) await _loadDashboard();
  }

  Future<void> _openListings() async {
    await Navigator.push(
      context,
      MaterialPageRoute<bool>(builder: (_) => const ListingEditorScreen()),
    );
    if (mounted) await _loadDashboard();
  }

  Future<void> _openBookings() async {
    await _openFilteredBookings();
  }

  Future<void> _openCalendar() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventorCalendar(initialBusiness: _selectedBusiness),
      ),
    );
    if (mounted) await _loadDashboard();
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  Future<void> _openFilteredBookings({
    String status = 'all',
    String period = 'all',
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => BookingsScreen(
          initialBusiness: _selectedBusiness,
          initialStatus: status,
          initialPeriod: period,
        ),
      ),
    );
    if (mounted) await _loadDashboard();
  }

  Future<void> _chooseBusiness() async {
    final selected = await showModalBottomSheet<ListingFilterSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (_) => ListingFilterSheet(
        selection: ListingFilterSelection(
          business: _selectedBusiness,
          sort: _bookingSort,
        ),
        businessOptions: {
          'all': AppSettingsScope.translate(
            context,
            "vendor.all_businesses.13312b22",
          ),
          'unassigned': AppSettingsScope.translate(
            context,
            "vendor.unassigned_bookings.79b7084c",
          ),
          for (final business in _allBusinesses) business.id: business.name,
        },
        categoryOptions: const {'all': 'All'},
        showCategory: false,
        showStatus: false,
        sortOptions: {
          'newest': AppSettingsScope.translate(
            context,
            "vendor.newest_bookings_first.0f2da6dd",
          ),
          'oldest': AppSettingsScope.translate(
            context,
            "vendor.oldest_bookings_first.14070228",
          ),
          'event_date': AppSettingsScope.translate(
            context,
            "vendor.event_date_earliest_first.d8410e02",
          ),
          'price_low': AppSettingsScope.translate(
            context,
            "vendor.amount_low_to_high.9822e914",
          ),
          'price_high': AppSettingsScope.translate(
            context,
            "vendor.amount_high_to_low.656aaa31",
          ),
        },
      ),
    );
    if (selected == null || !mounted) return;
    final businessChanged = selected.business != _selectedBusiness;
    setState(() {
      _selectedBusiness = selected.business;
      _bookingSort = selected.sort;
    });
    if (businessChanged) await _loadDashboard();
  }

  Future<void> _showBooking(BookingModel booking) async {
    if (_busyIds.contains(booking.id)) return;
    setState(() => _busyIds.add(booking.id));
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => BookingDetailsScreen(
            booking: booking,
            repository: widget.bookingRepository,
          ),
        ),
      );
      if (mounted) await _loadDashboard();
    } finally {
      if (mounted) setState(() => _busyIds.remove(booking.id));
    }
  }

  Future<void> _changeBooking(BookingModel booking, String status) async {
    if (_busyIds.contains(booking.id)) return;
    setState(() => _busyIds.add(booking.id));
    try {
      if (await confirmBookingChange(
        context,
        widget.bookingRepository ?? BookingRepository(),
        booking,
        status,
      )) {
        await _loadDashboard();
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(booking.id));
    }
  }

  Future<void> _openReviews({String? serviceId}) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ServiceReviewsScreen(
          serviceId: serviceId,
          businessId: serviceId == null && _selectedBusiness != 'all'
              ? _selectedBusiness
              : null,
          vendorMode: true,
        ),
      ),
    );
    if (mounted) await _loadDashboard();
  }

  Future<void> _showAlerts() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    if (mounted) {
      await _refreshInbox();
      await _loadDashboard();
    }
  }

  List<Widget> _buildUpgradeSections() {
    final pending = _bookings.where((b) => b.status == 'pending').toList();
    final upcoming = upcomingCommitments(_bookings);
    return [
      if (pending.isNotEmpty) ...[
        const SizedBox(height: 28),
        _buildSectionHeader(
          title: AppSettingsScope.translate(
            context,
            "vendor.needs_your_attention.8655e327",
          ),
          showAction: true,
          onAction: () => _openFilteredBookings(status: 'pending'),
        ),
        const SizedBox(height: 12),
        ...pending
            .take(3)
            .map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildBookingCard(b),
              ),
            ),
      ],
      const SizedBox(height: 28),
      _buildSectionHeader(
        title: AppSettingsScope.translate(
          context,
          "vendor.next_event.9fc6b07c",
        ),
      ),
      const SizedBox(height: 12),
      if (upcoming.isEmpty)
        _buildEmptyCard(
          icon: Icons.event_available_outlined,
          title: AppSettingsScope.translate(
            context,
            "vendor.no_upcoming_events.ff785ccc",
          ),
          subtitle: AppSettingsScope.translate(
            context,
            "vendor.accepted_events_will_appear_here.b92b4bd6",
          ),
          buttonText: AppSettingsScope.translate(
            context,
            "vendor.view_bookings.e578b0f8",
          ),
          onPressed: _openBookings,
        )
      else
        _buildBookingCard(upcoming.first),
      if (upcoming.length > 1) ...[
        const SizedBox(height: 28),
        _buildSectionHeader(
          title: AppSettingsScope.translate(
            context,
            "vendor.upcoming_events.e938bbbb",
          ),
          showAction: true,
          onAction: () =>
              _openFilteredBookings(status: 'accepted', period: 'upcoming'),
        ),
        const SizedBox(height: 12),
        ...upcoming
            .skip(1)
            .take(4)
            .map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildBookingCard(b),
              ),
            ),
      ],
      const SizedBox(height: 28),
      _buildSectionHeader(
        title: AppSettingsScope.translate(
          context,
          "vendor.recent_reviews.77e534db",
        ),
        showAction: true,
        onAction: _openReviews,
      ),
      const SizedBox(height: 12),
      if (_overview?.recentReviews.isEmpty ?? true)
        _buildEmptyCard(
          icon: Icons.star_border_rounded,
          title: AppSettingsScope.translate(
            context,
            "vendor.no_reviews_yet.8b670b7e",
          ),
          subtitle: AppSettingsScope.translate(
            context,
            "vendor.completed_booking_reviews_will_appear_here.ce136df0",
          ),
          buttonText: AppSettingsScope.translate(
            context,
            "vendor.view_reviews.dead5662",
          ),
          onPressed: _openReviews,
        ),
      if (_overview?.recentReviews.isNotEmpty == true) _buildRecentReviews(),
    ];
  }
}
