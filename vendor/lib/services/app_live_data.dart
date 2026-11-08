import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One authenticated socket per app. Payloads contain dataset revisions only.
class AppLiveData {
  static final instance = AppLiveData();
  final Set<LiveDataBinding> _bindings = {};
  final Map<String, int> _versions = {};
  SupabaseClient? _client;
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _auth;
  Timer? _fallback;
  String? _user;
  bool _connected = false, _started = false, _foreground = true;
  int? _readingGeneration;
  int _generation = 0;

  LiveDataBinding watch(
    Set<String> datasets,
    Future<void> Function(Set<String>) refresh,
  ) {
    final binding = LiveDataBinding(
      datasets,
      refresh,
      onDispose: (b) => _bindings.remove(b),
    );
    binding.setForeground(_foreground);
    _bindings.add(binding);
    return binding;
  }

  void setForeground(bool active) {
    _foreground = active;
    for (final binding in _bindings.toList()) {
      binding.setForeground(active);
    }
    if (active) unawaited(resync(force: true));
  }

  void invalidate(Set<String> datasets) {
    for (final binding in _bindings.toList()) {
      binding.invalidate(datasets);
    }
  }

  Future<void> start(SupabaseClient client) async {
    if (_started) return;
    _started = true;
    _client = client;
    _auth = client.auth.onAuthStateChange.listen((event) {
      final id = event.session?.user.id;
      if (id != _user) {
        unawaited(_connect());
      } else if (event.event == AuthChangeEvent.tokenRefreshed ||
          event.event == AuthChangeEvent.mfaChallengeVerified) {
        unawaited(resync());
      }
    });
    _fallback = Timer.periodic(const Duration(seconds: 45), (_) {
      // Offline sockets use a small revisions snapshot, not full-screen polling.
      if (!_connected && _foreground) unawaited(resync(force: true));
    });
    await _connect();
  }

  Future<void> _connect() async {
    final generation = ++_generation;
    final previous = _channel;
    _channel = null;
    _connected = false;
    _versions.clear();
    _user = _client?.auth.currentUser?.id;
    if (previous != null) unawaited(_client!.removeChannel(previous));
    if (_user == null || !_started) return;
    var subscribedOnce = false;
    try {
      _channel = _client!
          .channel('app-revisions-$_user-$generation')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'app_data_revisions',
            callback: (payload) {
              if (generation != _generation) return;
              _accept(payload.newRecord);
            },
          )
          .subscribe((status, error) {
            if (generation != _generation) return;
            _connected = status == RealtimeSubscribeStatus.subscribed;
            if (_connected) {
              unawaited(resync(force: subscribedOnce));
              subscribedOnce = true;
            }
          });
      await resync();
    } catch (_) {
      // Lists retain their last successful data. Resume/reconnect retries.
      _connected = false;
    }
  }

  void _accept(Map<String, dynamic> row) {
    final dataset = row['dataset'] as String?;
    final audience = row['audience'] as String?;
    final version = (row['version'] as num?)?.toInt();
    if (dataset == null || audience == null || version == null) return;
    final key = '$audience:$dataset';
    if ((_versions[key] ?? -1) >= version) return;
    _versions[key] = version;
    final scope = audience == 'public'
        ? 'public'
        : audience == 'admin'
        ? 'admin'
        : 'own';
    invalidate({dataset, '$scope:$dataset'});
  }

  Future<void> resync({bool force = false}) async {
    if (force && _user != null) {
      for (final b in _bindings.toList()) {
        b.invalidate(b.datasets);
      }
    }
    if (_client == null ||
        _user == null ||
        _readingGeneration == _generation ||
        !_started ||
        !_foreground) {
      return;
    }
    final generation = _generation;
    _readingGeneration = generation;
    try {
      final rows = await _client!
          .from('app_data_revisions')
          .select('audience,dataset,version')
          .inFilter('audience', ['public', 'user:$_user', 'admin']);
      if (generation != _generation || !_started) return;
      for (final row in rows) {
        _accept(row);
      }
    } catch (_) {
      // Connectivity failure must not clear cached screen data or spam toasts.
    } finally {
      if (_readingGeneration == generation) _readingGeneration = null;
    }
  }

  Future<void> stop() async {
    _started = false;
    _generation++;
    _user = null;
    _connected = false;
    _versions.clear();
    _fallback?.cancel();
    await _auth?.cancel();
    _auth = null;
    final channel = _channel;
    _channel = null;
    if (channel != null) await _client?.removeChannel(channel);
    _client = null;
  }
}

/// Coalesces bursts, defers hidden screens and serializes background refreshes.
class LiveDataBinding {
  final Set<String> datasets;
  final Future<void> Function(Set<String>) refresh;
  final void Function(LiveDataBinding)? onDispose;
  final Duration debounce;
  final Set<String> _dirty = {};
  Timer? _timer;
  bool _active = false, _running = false, _disposed = false, _foreground = true;
  int _retries = 0;
  LiveDataBinding(
    this.datasets,
    this.refresh, {
    this.onDispose,
    this.debounce = const Duration(milliseconds: 300),
  });
  void setActive(bool active) {
    if (_disposed) return;
    _active = active;
    if (active) {
      _schedule();
    } else {
      _timer?.cancel();
    }
  }

  void setForeground(bool active) {
    _foreground = active;
    if (active) {
      _schedule();
    } else {
      _timer?.cancel();
    }
  }

  void invalidate(Set<String> changed) {
    if (_disposed) return;
    if (_retries > 0) {
      _retries = 0;
      _timer?.cancel();
    }
    _dirty.addAll(
      changed.where((d) => datasets.contains('*') || datasets.contains(d)),
    );
    _schedule();
  }

  void _schedule() {
    if (!_active || !_foreground || _running || _disposed || _dirty.isEmpty) {
      return;
    }
    if (_timer?.isActive ?? false) return;
    _timer = Timer(
      _retries == 0 ? debounce : Duration(seconds: 1 << _retries),
      _flush,
    );
  }

  Future<void> _flush() async {
    if (!_active || !_foreground || _running || _disposed || _dirty.isEmpty) {
      return;
    }
    final changed = Set<String>.of(_dirty);
    _dirty.clear();
    _running = true;
    try {
      await refresh(changed);
      _retries = 0;
    } catch (_) {
      // Retry transient failures with bounded backoff, without losing old UI data.
      if (!_disposed && _retries < 3) {
        _retries++;
        _dirty.addAll(changed);
      }
    } finally {
      _running = false;
      _schedule();
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _dirty.clear();
    onDispose?.call(this);
  }
}

mixin LiveDataState<T extends StatefulWidget> on State<T> {
  Set<String> get liveDatasets;
  Future<void> onLiveData(Set<String> changed);
  LiveDataBinding? _live;
  bool liveRefreshing = false;
  bool get liveAlwaysActive => false;
  bool get liveCanRefresh => true;
  @override
  void initState() {
    super.initState();
    _live = AppLiveData.instance.watch(liveDatasets, (changed) async {
      if (!mounted) return;
      if (!liveCanRefresh) {
        _live?.invalidate(changed);
        await Future<void>.delayed(const Duration(milliseconds: 400));
        return;
      }
      liveRefreshing = true;
      try {
        await onLiveData(changed);
      } finally {
        liveRefreshing = false;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _live?.setActive(
      liveAlwaysActive ||
          (TickerMode.valuesOf(context).enabled &&
              (ModalRoute.of(context)?.isCurrent ?? true)),
    );
  }

  @override
  void dispose() {
    _live?.dispose();
    super.dispose();
  }
}

class AppLiveDataHost extends StatefulWidget {
  final SupabaseClient client;
  final Widget child;
  const AppLiveDataHost({super.key, required this.client, required this.child});
  @override
  State<AppLiveDataHost> createState() => _AppLiveDataHostState();
}

class _AppLiveDataHostState extends State<AppLiveDataHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(AppLiveData.instance.start(widget.client));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLiveData.instance.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(AppLiveData.instance.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
