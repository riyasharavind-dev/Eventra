import '../../services/customer_access.dart';
import '../../repositories/review_repository.dart';
import '../../widgets/reviews/review_editor_dialog.dart';

import 'package:flutter/material.dart';

import '../../models/booking_model.dart';
import '../../models/booking_list_filter.dart';
import '../../repositories/booking_repository.dart';
import '../../services/app_live_data.dart';
import '../../services/app_settings_controller.dart';
import '../../core/theme/app_icon_colors.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/global_search_bar.dart';
import '../../widgets/bookings/customer_booking_card.dart';
import '../../widgets/bookings/booking_ui.dart';
import '../extended/eventor_calendar.dart';
import '../extended/booking_details_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({
    super.key,
    this.repository,
    this.onOpen,
    this.initialStatus = 'all',
  });
  final BookingRepository? repository;
  final ValueChanged<BookingModel>? onOpen;
  final String initialStatus;
  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with LiveDataState<BookingsScreen> {
  @override
  Set<String> get liveDatasets => {
    'own:bookings',
    'own:booking_status_history',
    'public:services',
    'public:businesses',
  };
  @override
  Future<void> onLiveData(Set<String> changed) => load(quiet: true);
  late final repo = widget.repository ?? BookingRepository();
  final search = TextEditingController();
  List<BookingModel> bookings = [];
  late String status = widget.initialStatus;
  bool loading = true;
  Object? error;
  int generation = 0;
  String t(String en, String ta) => AppSettingsScope.of(context).text(en, ta);
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load({bool quiet = false}) async {
    if (widget.repository == null && !CustomerAccess.signedIn) {
      setState(() {
        bookings = [];
        loading = false;
        error = null;
      });
      return;
    }
    final request = ++generation;
    setState(() {
      if (!quiet) loading = bookings.isEmpty;
      error = null;
    });
    try {
      final result = await repo.getMyBookings();
      if (!mounted || request != generation) return;
      setState(() {
        bookings = result;
        loading = false;
      });
    } catch (e) {
      if (mounted && request == generation) {
        setState(() {
          error = e;
          loading = false;
        });
      }
    }
  }

  Future<void> open(BookingModel booking) async {
    if (widget.onOpen != null) {
      widget.onOpen!(booking);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            BookingDetailsScreen(booking: booking, repository: repo),
      ),
    );
    if (mounted) await load(quiet: true);
  }

  Future<void> giveReview(BookingModel booking) async {
    try {
      final reviews = ReviewRepository();
      final contextData = await reviews.bookingContext(booking.id);
      if (!mounted) return;
      if (!contextData.canReview) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppSettingsScope.translate(
                context,
                "customer.confirm_event_completion_before_reviewing.79e26952",
              ),
            ),
          ),
        );
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            ReviewEditorDialog(booking: contextData, repository: reviews),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppSettingsScope.translate(
                context,
                "customer.unable_to_open_review_please_retry.4d9bc864",
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> calendar() async {
    if (widget.repository == null &&
        !await CustomerAccess.requireSignIn(context)) { return; }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EventorCalendar(repository: repo, initialStatus: status),
      ),
    );
    if (mounted) await load(quiet: true);
  }

  @override
  Widget build(BuildContext context) {
    const wine = Color(0xFF80152C), ink = Color(0xFF17171B);
    final base = filterCustomerBookings(bookings, query: search.text);
    final rows = filterCustomerBookings(
      bookings,
      query: search.text,
      status: status,
    );
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      body: SafeArea(
        child: AppShimmerRefreshIndicator(
          onRefresh: load,
          color: wine,
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('Bookings', 'முன்பதிவுகள்'),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: GlobalSearchBar(
                              controller: search,
                              onChanged: (_) => setState(() {}),
                              hintText: t(
                                'Search vendor, service or location',
                                'விற்பனையாளர், சேவை அல்லது இடத்தைத் தேடுங்கள்',
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Container(
                            width: 49,
                            height: 49,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFF0EDF0)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x06000000),
                                  blurRadius: 10,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              key: const ValueKey('open-booking-calendar'),
                              tooltip: t(
                                'Open booking calendar',
                                'முன்பதிவு நாட்காட்டியைத் திற',
                              ),
                              onPressed: calendar,
                              icon: const Icon(
                                Icons.calendar_month_outlined,
                                color: AppIconColors.standard,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '${rows.length} ${t(rows.length == 1 ? 'booking' : 'bookings', 'முன்பதிவுகள்')}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final value in [
                              'all',
                              'pending',
                              'accepted',
                              'completed',
                              'rejected',
                              'cancelled',
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  key: ValueKey('booking-status-$value'),
                                  label: Text(
                                    '${value == 'all' ? t('All', 'அனைத்தும்') : bookingStatus(context, value)} (${value == 'all' ? base.length : base.where((b) => b.status == value).length})',
                                  ),
                                  selected: status == value,
                                  showCheckmark: false,
                                  labelStyle: TextStyle(
                                    color: status == value ? Colors.white : ink,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  side: BorderSide(
                                    color: status == value
                                        ? wine
                                        : const Color(0xFFECEAF0),
                                  ),
                                  backgroundColor: Colors.white,
                                  selectedColor: wine,
                                  onSelected: (_) =>
                                      setState(() => status = value),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  t(
                                    bookings.isEmpty
                                        ? 'Could not load bookings. Please try again.'
                                        : 'Refresh failed. Showing previously loaded bookings.',
                                    'முன்பதிவுகளை ஏற்ற முடியவில்லை. மீண்டும் முயற்சி.',
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: load,
                                child: Text(t('Retry', 'மீண்டும் முயற்சி')),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (loading && bookings.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppContentSkeleton(layout: SkeletonLayout.bookings),
                )
              else if (rows.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: AppEmptyState(
                        icon: Icons.calendar_today_outlined,
                        title: t(
                          bookings.isEmpty
                              ? 'No bookings yet'
                              : 'No matching bookings',
                          bookings.isEmpty
                              ? 'முன்பதிவுகள் இல்லை'
                              : 'பொருந்தும் முன்பதிவுகள் இல்லை',
                        ),
                        message: bookings.isEmpty
                            ? t(
                                'Explore services and book for your upcoming events.',
                                'வரவிருக்கும் நிகழ்வுகளுக்கு சேவைகளை ஆராய்ந்து முன்பதிவு செய்யுங்கள்.',
                              )
                            : t(
                                'Try adjusting your search or filters.',
                                'தேடல் அல்லது வடிப்பான்களை மாற்ற முயற்சிக்கவும்.',
                              ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 130),
                  sliver: SliverList.builder(
                    itemCount: rows.length,
                    itemBuilder: (_, index) => CustomerBookingCard(
                      key: ValueKey(rows[index].id),
                      booking: rows[index],
                      busy: false,
                      onOpen: () => open(rows[index]),
                      onReview: rows[index].status == 'completed'
                          ? () => giveReview(rows[index])
                          : null,
                      onAcknowledged: () => load(quiet: true),
                      repository: repo,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
