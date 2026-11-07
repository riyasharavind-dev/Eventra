import '../../widgets/vendor_page_scaffold.dart';
import '../../widgets/common/app_shimmer.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/vendor_notification.dart';
import '../../repositories/vendor_notifications_repository.dart';
import '../../services/vendor_notification_router.dart';
import '../../widgets/notifications/notification_tile.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.repository, this.onOpen});
  final VendorNotificationsRepository? repository;
  final Future<void> Function(VendorNotification)? onOpen;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with WidgetsBindingObserver {
  late final VendorNotificationsRepository repo;
  RealtimeChannel? channel;
  Timer? debounce, reconcile;
  final rows = <VendorNotification>[];
  final opening = <String>{};
  String filter = 'all';
  bool loading = true, more = false, hasMore = false, marking = false;
  int generation = 0, unread = 0;
  Object? error;
  DateTime loadedThrough = DateTime.now();
  static const wine = Color(0xFF80152C);
  static const filters = {
    'all': 'All',
    'unread': 'Unread',
    'booking': 'Bookings',
    'payment': 'Payments',
    'review': 'Reviews',
    'offer': 'Offers',
    'updates': 'Updates',
  };
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    repo = widget.repository ?? VendorNotificationsRepository();
    channel = repo.watch(_scheduleRefresh);
    reconcile = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _scheduleRefresh(),
    );
    load();
  }

  void _scheduleRefresh() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) load(silent: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) load(silent: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    debounce?.cancel();
    reconcile?.cancel();
    if (channel != null) unawaited(repo.stopWatching(channel!));
    super.dispose();
  }

  Future<void> load({bool silent = false}) async {
    final request = ++generation, selected = filter;
    final through = DateTime.now();
    final keepCount = silent ? rows.length : 0;
    if (!silent) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      await repo.syncAnnouncements();
      final result = await Future.wait<dynamic>([
        repo.load(filter: selected),
        repo.unreadCount(),
      ]);
      final fresh = List<VendorNotification>.from(result[0] as List);
      var lastPageSize = fresh.length;
      while (fresh.length < keepCount &&
          lastPageSize == VendorNotificationsRepository.pageSize) {
        if (!mounted || request != generation) return;
        final page = await repo.load(filter: selected, before: fresh.last);
        lastPageSize = page.length;
        fresh.addAll(page);
      }
      if (!mounted || request != generation) return;
      setState(() {
        rows
          ..clear()
          ..addAll(fresh);
        unread = result[1] as int;
        hasMore = lastPageSize == VendorNotificationsRepository.pageSize;
        loading = false;
        more = false;
        error = null;
        loadedThrough = through;
      });
    } catch (e) {
      if (mounted && request == generation) {
        setState(() {
          error = e;
          loading = false;
          more = false;
        });
      }
    }
  }

  Future<void> loadMore() async {
    if (more || loading || !hasMore || rows.isEmpty) return;
    final request = generation;
    setState(() => more = true);
    try {
      final page = await repo.load(filter: filter, before: rows.last);
      if (!mounted || request != generation) return;
      setState(() {
        final ids = rows.map((e) => e.id).toSet();
        rows.addAll(page.where((e) => !ids.contains(e.id)));
        hasMore = page.length == VendorNotificationsRepository.pageSize;
      });
    } catch (_) {
      if (mounted && request == generation) {
        _snack('Unable to load older notifications. Please try again.');
      }
    } finally {
      if (mounted && request == generation) setState(() => more = false);
    }
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
  Future<void> open(VendorNotification item) async {
    if (opening.contains(item.id)) return;
    setState(() => opening.add(item.id));
    try {
      if (item.unread) {
        await repo.markRead(item);
        if (!mounted) return;
        setState(() {
          final index = rows.indexWhere((r) => r.id == item.id);
          if (index >= 0) {
            if (filter == 'unread') {
              rows.removeAt(index);
            } else {
              rows[index] = item.asRead(DateTime.now());
            }
          }
          unread = unread > 0 ? unread - 1 : 0;
        });
      }
      if (!mounted) return;
      if (widget.onOpen != null) {
        await widget.onOpen!(item);
      } else {
        await openVendorNotification(context, item);
      }
    } catch (_) {
      if (mounted) {
        _snack(
          'Unable to open this update. It may no longer be available. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => opening.remove(item.id));
    }
  }

  Future<void> markAll() async {
    if (marking || loading) return;
    setState(() => marking = true);
    try {
      await repo.markAllRead(loadedThrough);
      if (mounted) await load(silent: true);
    } catch (_) {
      if (mounted) {
        _snack('Unable to mark notifications as read. Please try again.');
      }
    } finally {
      if (mounted) setState(() => marking = false);
    }
  }

  Widget empty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(
            radius: 36,
            backgroundColor: Color(0xFFF4E6EB),
            child: Icon(
              Icons.notifications_none_rounded,
              color: wine,
              size: 34,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            filter == 'unread'
                ? 'You’re all caught up'
                : filter == 'all'
                ? 'No notifications yet'
                : 'No ${filters[filter]!.toLowerCase()} yet',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your activity and updates will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF77717A)),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return VendorPageScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: marking || loading ? null : markAll,
              child: Text(
                marking ? 'Saving…' : 'Mark all read',
                style: const TextStyle(color: wine, fontSize: 12),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              children: [
                for (final f in filters.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.value),
                      selected: filter == f.key,
                      showCheckmark: false,
                      selectedColor: wine,
                      labelStyle: TextStyle(
                        color: filter == f.key
                            ? Colors.white
                            : const Color(0xFF615962),
                      ),
                      side: BorderSide.none,
                      backgroundColor: const Color(0xFFF4F2F4),
                      onSelected: (_) {
                        if (filter != f.key) {
                          setState(() {
                            filter = f.key;
                            rows.clear();
                            hasMore = false;
                          });
                          load();
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (error != null && rows.isNotEmpty)
            TextButton.icon(
              onPressed: () => load(),
              icon: const Icon(Icons.refresh),
              label: const Text('Unable to refresh. Retry'),
            ),
          Expanded(
            child: AppShimmerRefreshIndicator(
              color: wine,
              onRefresh: () => load(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (loading && rows.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: AppContentSkeleton(
                          layout: SkeletonLayout.listings,
                        ),
                      ),
                    )
                  else if (error != null && rows.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Unable to load notifications.'),
                            TextButton(
                              onPressed: () => load(),
                              child: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (rows.isEmpty)
                    SliverFillRemaining(hasScrollBody: false, child: empty())
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final item = rows[index],
                            group = notificationDateGroup(item.createdAt, now);
                        final showGroup =
                            index == 0 ||
                            notificationDateGroup(
                                  rows[index - 1].createdAt,
                                  now,
                                ) !=
                                group;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showGroup)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  22,
                                  18,
                                  8,
                                ),
                                child: Text(
                                  group,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            NotificationTile(
                              key: ValueKey(item.id),
                              item: item,
                              onTap: () => open(item),
                              busy: opening.contains(item.id),
                            ),
                          ],
                        );
                      }, childCount: rows.length),
                    ),
                  if (hasMore)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextButton(
                          onPressed: more ? null : loadMore,
                          child: Text(
                            more ? 'Loading…' : 'Load older notifications',
                          ),
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
