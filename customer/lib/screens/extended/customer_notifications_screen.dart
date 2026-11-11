import '../../services/customer_access.dart';
import '../../core/theme/app_icon_colors.dart';
import '../../widgets/common/app_empty_state.dart';

import 'package:eventor_customer/services/app_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/booking_model.dart';
import '../../repositories/booking_repository.dart';
import '../../services/app_live_data.dart';
import '../../widgets/notifications/customer_notification_card.dart';
import 'booking_details_screen.dart';
import 'notifications_screen.dart';

class CustomerNotificationsScreen extends StatefulWidget {
  const CustomerNotificationsScreen({super.key});
  @override
  State<CustomerNotificationsScreen> createState() =>
      _CustomerNotificationsScreenState();
}

class _CustomerNotificationsScreenState
    extends State<CustomerNotificationsScreen>
    with LiveDataState<CustomerNotificationsScreen> {
  final repo = BookingRepository();
  List<BookingModel> items = [];
  Set<String> read = {};
  bool loading = true, failed = false;
  int generation = 0;
  String filter = 'all';
  String get readKey =>
      'customer.notification.read.${Supabase.instance.client.auth.currentUser?.id}';
  DateTime timestamp(BookingModel b) =>
      (b.awaitingCompletion
              ? b.vendorCompletedAt!
              : b.customerCompletedAt ??
                    b.updatedAt ??
                    b.createdAt ??
                    b.eventDate)
          .toLocal();
  String fingerprint(BookingModel b) =>
      '${b.id}:${b.status}:${b.vendorCompletedAt}:${b.customerCompletedAt}:${b.updatedAt}';
  @override
  Set<String> get liveDatasets => {'own:bookings'};
  @override
  Future<void> onLiveData(Set<String> changed) => load();
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (!CustomerAccess.signedIn) {
      setState(() {
        items = [];
        read = {};
        loading = false;
        failed = false;
      });
      return;
    }
    final request = ++generation;
    try {
      final prefs = await SharedPreferences.getInstance();
      final rows = await repo.getMyBookings();
      if (!mounted || request != generation) return;
      final unique = {for (final row in rows) row.id: row}.values.toList()
        ..sort((a, b) => timestamp(b).compareTo(timestamp(a)));
      setState(() {
        items = unique;
        read = (prefs.getStringList(readKey) ?? []).toSet();
        loading = false;
        failed = false;
      });
    } catch (_) {
      if (mounted && request == generation) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  Future<void> open(BookingModel item) async {
    setState(() => read.add(fingerprint(item)));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      readKey,
      read.toList().reversed.take(500).toList(),
    );
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => BookingDetailsScreen(booking: item),
      ),
    );
  }

  String group(BookingModel b) {
    final now = DateUtils.dateOnly(DateTime.now());
    final date = DateUtils.dateOnly(timestamp(b));
    if (date == now) return 'Today';
    if (date == DateTime(now.year, now.month, now.day - 1)) return 'Yesterday';
    return 'Earlier';
  }

  String timeLabel(BuildContext context, BookingModel b) {
    final date = timestamp(b);
    if (group(b) != 'Earlier') {
      return MaterialLocalizations.of(context)
          .formatTimeOfDay(TimeOfDay.fromDateTime(date));
    }
    return MaterialLocalizations.of(context).formatShortDate(date);
  }

  static const filters = {
    'all': ('All', Icons.notifications_none_rounded),
    'booking': ('Bookings', Icons.calendar_today_outlined),
    'offer': ('Offers', Icons.sell_outlined),
    'updates': ('Updates', Icons.campaign_outlined),
    'others': ('Others', Icons.star_border_rounded),
  };
  @override
  Widget build(BuildContext context) {
    final visible = filter == 'all' || filter == 'booking'
        ? items
        : <BookingModel>[];
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color(0xFFF8F8FA),
        elevation: 0,
        title: Text(
          AppSettingsScope.translate(
            context,
            "customer.notifications.78801183",
          ),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Color(0xFF17171B),
          ),
        ),
        actions: [
          IconButton(
            tooltip: AppSettingsScope.translate(
              context,
              "customer.notification_settings.63568f05",
            ),
            icon: const Icon(Icons.settings_outlined, color: AppIconColors.standard),
            onPressed: () =>
                CustomerAccess.open(context, const NotificationsScreen()),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF80152C),
        onRefresh: load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
          children: [
            SizedBox(
              height: 38,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: filters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final key = filters.keys.elementAt(index),
                      value = filters.values.elementAt(index);
                  final selected = filter == key;
                  return Material(
                    color: selected
                        ? const Color(0xFF80152C)
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: selected
                            ? const Color(0xFF80152C)
                            : const Color(0xFFF0EDF0),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => filter = key),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            Icon(
                              value.$2,
                              size: 18,
                              color: selected
                                  ? Colors.white
                                  : AppIconColors.standard,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              value.$1,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF17171B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            if (loading)
              const LinearProgressIndicator(color: Color(0xFF80152C)),
            if (failed)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF80152C),
                    ),
                    onPressed: load,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      AppSettingsScope.translate(
                        context,
                        "customer.unable_to_load_notifications_retry.4ee7e49a",
                      ),
                    ),
                  ),
                ),
              ),
            if (!loading && !failed && visible.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: AppEmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: AppSettingsScope.translate(
                    context,
                    "customer.no_notifications_yet.37ecf360",
                  ),
                  message: 'Updates about your bookings and service requests will appear here.',
                ),
              ),
            for (final section in ['Today', 'Yesterday', 'Earlier']) ...[
              if (visible.any((b) => group(b) == section))
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Text(
                    section,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF73737D),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              for (final b in visible.where((b) => group(b) == section))
                CustomerNotificationCard(
                  key: ValueKey(b.id),
                  booking: b,
                  timeLabel: timeLabel(context, b),
                  unread: !read.contains(fingerprint(b)),
                  onTap: () => open(b),
                  onConfirmed: load,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
