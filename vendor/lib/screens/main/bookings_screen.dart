import '../../widgets/common/app_shimmer.dart';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

import '../extended/eventra_calendar.dart';
import '../../models/booking_model.dart';
import '../../widgets/bookings/vendor_booking_card.dart';
import '../../widgets/common/global_search_bar.dart';
import '../../models/booking_list_filter.dart';
import '../../repositories/booking_repository.dart';
import '../extended/booking_details_screen.dart';
import '../../widgets/bookings/booking_ui.dart';

class BookingsScreen extends StatefulWidget {
  final BookingRepository? repository;
  final String initialStatus, initialBusiness, initialPeriod;

  const BookingsScreen({
    super.key,
    this.repository,
    this.initialStatus = 'all',
    this.initialBusiness = 'all',
    this.initialPeriod = 'all',
  });

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen>
    with WidgetsBindingObserver {
  late final BookingRepository repo;
  RealtimeChannel? _bookingChannel;
  StreamSubscription<RemoteMessage>? _bookingMessages;
  Timer? _refreshDebounce;

  final TextEditingController search = TextEditingController();
  final Set<String> busyIds = {};
  List<BookingModel> bookings = [];

  bool loading = true;
  Object? error;
  int generation = 0;

  String status = 'all';
  String business = 'all';
  String period = 'all';
  String dateFilter = 'all';
  String sort = 'newest';

  DateTimeRange? range;

  String t(String en, String ta) => bookingText(context, en, ta);

  static const Color _wine = Color(0xFF80152C);
  static const Color _pageBg = Color(0xFFF8F8FA);
  static const Color _ink = Color(0xFF17171B);
  static const Color _muted = Color(0xFF777783);

  @override
  void initState() {
    super.initState();
    repo = widget.repository ?? BookingRepository();
    status = widget.initialStatus;
    business = widget.initialBusiness;
    period = widget.initialPeriod;
    WidgetsBinding.instance.addObserver(this);
    _bookingChannel = repo.watchBookings(_scheduleRefresh);
    // Push delivery also refreshes the open list, independently of database
    // publication setup. Realtime covers devices with notifications disabled.
    _bookingMessages = FirebaseMessaging.onMessage.listen((message) {
      if (message.data['type'] == 'new_booking' &&
          message.data['vendor_id'] == repo.vendorId) {
        _scheduleRefresh();
      }
    });
    load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshDebounce?.cancel();
    unawaited(_bookingMessages?.cancel());
    final channel = _bookingChannel;
    if (channel != null) unawaited(repo.stopWatching(channel));
    search.dispose();
    super.dispose();
  }

  void _scheduleRefresh() {
    if (!mounted) return;
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) unawaited(load(quiet: true));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scheduleRefresh();
  }

  Future<void> load({bool quiet = false}) async {
    if (!mounted) return;

    final current = ++generation;

    setState(() {
      if (!quiet) loading = true;
      error = null;
    });

    try {
      final rows = await repo.getVendorBookings(repo.vendorId);

      if (!mounted || current != generation) return;

      setState(() {
        bookings = rows;
        loading = false;
      });
    } catch (e) {
      if (!mounted || current != generation) return;

      setState(() {
        if (!quiet || bookings.isEmpty) error = e;
        loading = false;
      });
    }
  }

  List<BookingModel> filtered({String? selectedStatus}) {
    return filterVendorBookings(
      bookings,
      status: selectedStatus ?? status,
      business: business,
      period: period,
      dateFilter: dateFilter,
      rangeStart: range?.start,
      rangeEnd: range?.end,
      query: search.text,
      sort: sort,
    );
  }

  Map<String, String> get businesses => {
    'all': t('All businesses', 'அனைத்து வணிகங்கள்'),
    for (final b in bookings)
      if (b.businessId != null)
        b.businessId!:
            b.businessName ?? t('Unnamed business', 'பெயரிடப்படாத வணிகம்'),
    if (bookings.any((b) => b.businessId == null))
      'unassigned': t('Unassigned business', 'வணிகம் ஒதுக்கப்படவில்லை'),
  };

  Map<String, String> get periods => {
    'all': t('All events', 'அனைத்து நிகழ்வுகள்'),
    'upcoming': t('Upcoming / ongoing', 'வரவிருக்கும் / நடைபெறும்'),
    'past': t('Past events', 'கடந்த நிகழ்வுகள்'),
  };

  Map<String, String> get dateOptions => {
    'all': t('Any date', 'அனைத்து தேதிகள்'),
    'today': t('Today', 'இன்று'),
    'week': t('Next 7 days', 'அடுத்த 7 நாட்கள்'),
    'month': t('This month', 'இந்த மாதம்'),
    'custom': t('Custom dates', 'தேதிகளைத் தேர்வு செய்'),
  };

  Map<String, String> get sorts => {
    'event': t(
      'Event date · nearest first',
      'நிகழ்வு தேதி · அருகிலுள்ளவை முதலில்',
    ),
    'newest': t('Newest requests first', 'புதிய கோரிக்கைகள் முதலில்'),
  };

  int get filterCount =>
      (business != 'all' ? 1 : 0) +
      (period != 'all' ? 1 : 0) +
      (dateFilter != 'all' ? 1 : 0) +
      (sort != 'newest' ? 1 : 0);

  Future<void> openCalendar() async {
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            EventraCalendar(initialBusiness: business, initialStatus: status),
      ),
    );
    if (mounted) {
      await load();
    }
  }

  Future<void> action(BookingModel b, String target) async {
    if (busyIds.contains(b.id)) return;

    setState(() => busyIds.add(b.id));

    try {
      if (await confirmBookingChange(context, repo, b, target)) {
        await load();
      }
    } finally {
      if (mounted) {
        setState(() => busyIds.remove(b.id));
      }
    }
  }

  Future<void> details(BookingModel b) async {
    if (busyIds.contains(b.id)) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BookingDetailsScreen(booking: b, repository: repo),
      ),
    );

    if (mounted) {
      await load();
    }
  }

  Widget message(String title, {String? detail}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              error == null
                  ? Icons.event_note_outlined
                  : Icons.cloud_off_outlined,
              size: 48,
              color: _wine,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted),
              ),
            ],
            if (error != null)
              TextButton(
                onPressed: load,
                child: Text(t('Retry', 'மீண்டும் முயற்சி')),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = filtered();
    final base = filtered(selectedStatus: 'all');

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme
            .copyWith(primary: _wine, secondary: _wine, surface: Colors.white),
        scaffoldBackgroundColor: _pageBg,
        chipTheme: Theme.of(context).chipTheme.copyWith(
          selectedColor: _wine,
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFECEAF0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _wine,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: _pageBg,
        body: SafeArea(
          child: AppShimmerRefreshIndicator(
            color: _wine,
            onRefresh: load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Heading only — reload icon removed completely.
                        Text(
                          t('Bookings', 'முன்பதிவுகள்'),
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 29,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Search bar directly below the heading.
                        Row(
                          children: [
                            Expanded(
                              child: GlobalSearchBar(
                                controller: search,
                                onChanged: (_) => setState(() {}),
                                hintText: t(
                                  'Search customer, service or location...',
                                  'வாடிக்கையாளர், சேவை அல்லது இடம் தேடு...',
                                ),
                                clearLabel: t('Clear search', 'தேடலை அழி'),
                              ),
                            ),
                            const SizedBox(width: 9),
                            SizedBox(
                              width: 49,
                              height: 49,
                              child: IconButton.outlined(
                                tooltip: t(
                                  'Open booking calendar',
                                  'முன்பதிவு நாட்காட்டியைத் திற',
                                ),
                                onPressed: openCalendar,
                                style: IconButton.styleFrom(
                                  foregroundColor: _wine,
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: Color(0xFFE8E5EB),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                icon: const Icon(Icons.calendar_month_outlined),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${rows.length} ${t('bookings', 'முன்பதிவுகள்')}',
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (filterCount > 0)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    business = 'all';
                                    period = 'all';
                                    dateFilter = 'all';
                                    sort = 'newest';
                                    range = null;
                                  });
                                },
                                child: Text(
                                  t('Clear filters', 'வடிகட்டல்களை நீக்கு'),
                                  style: const TextStyle(color: _wine),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children:
                                [
                                  'all',
                                  'pending',
                                  'accepted',
                                  'completed',
                                  'rejected',
                                  'cancelled',
                                ].map((s) {
                                  final selected = status == s;

                                  final count = s == 'all'
                                      ? base.length
                                      : base.where((b) => b.status == s).length;

                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(
                                        '${s == 'all' ? t('All', 'அனைத்தும்') : bookingStatus(context, s)} ($count)',
                                      ),
                                      selected: selected,
                                      showCheckmark: false,
                                      labelStyle: TextStyle(
                                        color: selected ? Colors.white : _ink,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      side: BorderSide(
                                        color: selected
                                            ? _wine
                                            : const Color(0xFFECEAF0),
                                      ),
                                      backgroundColor: Colors.white,
                                      selectedColor: _wine,
                                      onSelected: (_) {
                                        setState(() => status = s);
                                      },
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),

                        if (filterCount > 0) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (business != 'all')
                                Chip(
                                  label: Text(
                                    businesses[business] ??
                                        t('Business', 'வணிகம்'),
                                  ),
                                ),
                              if (period != 'all')
                                Chip(label: Text(periods[period]!)),
                              if (dateFilter != 'all')
                                Chip(
                                  label: Text(
                                    dateFilter == 'custom' && range != null
                                        ? '${bookingDate(context, range!.start)} – ${bookingDate(context, range!.end)}'
                                        : dateOptions[dateFilter]!,
                                  ),
                                ),
                              if (sort != 'newest')
                                Chip(label: Text(sorts[sort]!)),
                            ],
                          ),
                        ],

                        if (loading && bookings.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const ShimmerLoadingBar(color: _wine),
                        ],

                        if (error != null && bookings.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEDEF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: ListTile(
                              dense: true,
                              title: Text(
                                t(
                                  'Refresh failed. Showing previously loaded bookings.',
                                  'புதுப்பிக்க முடியவில்லை. ஏற்கனவே ஏற்றப்பட்ட முன்பதிவுகள் காட்டப்படுகின்றன.',
                                ),
                              ),
                              trailing: IconButton(
                                onPressed: load,
                                tooltip: t('Retry', 'மீண்டும் முயற்சி'),
                                icon: const Icon(Icons.refresh, color: _wine),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                if (loading && bookings.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: AppContentSkeleton(
                        layout: SkeletonLayout.bookings,
                      ),
                    ),
                  )
                else if (error != null && bookings.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: message(
                      t(
                        'Unable to load bookings',
                        'முன்பதிவுகளை ஏற்ற முடியவில்லை',
                      ),
                    ),
                  )
                else if (rows.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: message(
                      bookings.isEmpty
                          ? t('No bookings yet', 'இன்னும் முன்பதிவுகள் இல்லை')
                          : t(
                              'No matching bookings',
                              'பொருத்தமான முன்பதிவுகள் இல்லை',
                            ),
                      detail: bookings.isEmpty
                          ? t(
                              'New customer requests will appear here.',
                              'புதிய வாடிக்கையாளர் கோரிக்கைகள் இங்கே தோன்றும்.',
                            )
                          : t(
                              'Try another search or change the filters.',
                              'வேறு தேடல் அல்லது வடிகட்டலை முயற்சிக்கவும்.',
                            ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 128),
                    sliver: SliverList.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final booking = rows[index];

                        final card = VendorBookingCard(
                          booking: booking,
                          busy: busyIds.contains(booking.id),
                          onOpen: () => details(booking),
                          onAccept: () => action(booking, 'accepted'),
                          onReject: () => action(booking, 'rejected'),
                          onComplete: () => action(booking, 'completed'),
                        );

                        String section(BookingModel item) {
                          final eventDate = item.eventDate;

                          if (eventDate == null) {
                            return t(
                              'Date not specified',
                              'தேதி குறிப்பிடப்படவில்லை',
                            );
                          }

                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);

                          final day = DateTime(
                            eventDate.year,
                            eventDate.month,
                            eventDate.day,
                          );

                          if (day == today) {
                            return t('Today', 'இன்று');
                          }

                          if (day.isBefore(today)) {
                            return t('Past bookings', 'கடந்த முன்பதிவுகள்');
                          }

                          return t(
                            'Upcoming bookings',
                            'வரவிருக்கும் முன்பதிவுகள்',
                          );
                        }

                        final heading = section(booking);
                        final showHeading =
                            sort == 'event' &&
                            (index == 0 || section(rows[index - 1]) != heading);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showHeading)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  2,
                                  16,
                                  2,
                                  10,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: _wine,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                    ),
                                    const SizedBox(width: 9),
                                    Text(
                                      heading,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: _ink,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      sort == 'newest'
                                          ? '${rows.length}'
                                          : '${rows.where((item) => section(item) == heading).length}',
                                      style: const TextStyle(
                                        color: _muted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            card,
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
