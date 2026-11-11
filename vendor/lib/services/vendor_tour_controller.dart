import 'dart:async';

import 'package:flutter/material.dart';

import '../models/vendor_tour_step.dart';
import '../repositories/onboarding_repository.dart';
import 'vendor_navigation_controller.dart';

abstract final class TourTargets {
  static const listings = 'nav-listings';
  static const add = 'listings-add';
  static const business = 'menu-add-business';
  static const category = 'business-category';
  static const calendar = 'bookings-calendar';
  static const dates = 'calendar-dates';
  static const language = 'me-language';
  static const languages = 'language-options';
}

class VendorTourController extends ChangeNotifier {
  VendorTourController({VendorNavigationController? navigation})
    : navigation = navigation ?? VendorNavigationController.instance;
  static final instance = VendorTourController();
  final VendorNavigationController navigation;
  final Map<String, Map<Object, GlobalKey>> _targets = {};
  OnboardingRepository? _repository;
  String? _owner;
  int step = 0;
  bool active = false, busy = false, calendarOpened = false;
  bool _scheduled = false;
  int _generation = 0;
  bool get ownerMatches => _repository?.accountId == _owner;
  void register(String id, Object owner, GlobalKey key) {
    (_targets[id] ??= {})[owner] = key;
    _changed();
  }

  void unregister(String id, Object owner) {
    _targets[id]?.remove(owner);
    _changed();
  }

  GlobalKey? target(String id) {
    for (final key
        in (_targets[id]?.values ?? const <GlobalKey>[]).toList().reversed) {
      final context = key.currentContext;
      if (context == null ||
          !context.mounted ||
          !TickerMode.valuesOf(context).enabled) {
        continue;
      }
      if (ModalRoute.of(context)?.isCurrent == false) continue;
      final box = context.findRenderObject();
      if (box is RenderBox &&
          box.attached &&
          box.hasSize &&
          !box.size.isEmpty) {
        return key;
      }
    }
    return null;
  }

  String get targetId => switch (step) {
    0 => TourTargets.listings,
    1 => TourTargets.add,
    2 =>
      target(TourTargets.business) != null
          ? TourTargets.business
          : TourTargets.add,
    3 =>
      target(TourTargets.category) != null
          ? TourTargets.category
          : target(TourTargets.add) != null
          ? TourTargets.add
          : TourTargets.category,
    4 => calendarOpened ? TourTargets.dates : TourTargets.calendar,
    _ =>
      target(TourTargets.languages) != null
          ? TourTargets.languages
          : TourTargets.language,
  };
  bool get canContinue =>
      step == 3 || (step == 4 && calendarOpened) || step == 5;
  Future<void> start({
    OnboardingRepository? repository,
    bool restart = false,
    VendorGuideProgress? progress,
  }) async {
    final generation = ++_generation;
    _repository = repository ?? OnboardingRepository();
    _owner = _repository!.accountId;
    if (_owner == null || !navigation.active) return;
    busy = true;
    try {
      final state =
          progress ??
          (restart
              ? const VendorGuideProgress()
              : await _repository!.loadProgress());
      if (generation != _generation || !ownerMatches) return;
      step = restart || state.step >= 6 ? 0 : state.step;
      // Resume the click path rather than reopening an editable form automatically.
      if (step == 2 || step == 3) step = 1;
      final index = step == 0
          ? 0
          : step <= 3
          ? 1
          : step == 4
          ? 2
          : 3;
      await navigation.select(index);
      if (generation != _generation ||
          !ownerMatches ||
          navigation.index != index) {
        return;
      }
      calendarOpened = false;
      active = true;
      _changed();
      if (restart) {
        await _repository!.saveProgress(
          const VendorGuideProgress(status: 'in_progress'),
          restart: true,
        );
      }
    } finally {
      if (generation == _generation) {
        busy = false;
        _changed();
      }
    }
  }

  void tabSelected(int index) {
    if (active && !busy && step == 0 && index == 1) _advance(1);
  }

  void menuOpened() {
    if (active && !busy && step >= 1 && step <= 3) _advance(2);
  }

  void calendarOpenedNow() {
    if (active && step == 4) {
      calendarOpened = true;
      _changed();
    }
  }

  void businessOpened() {
    if (active && !busy && step == 2) _advance(3);
  }

  void _advance(int value) {
    if (!ownerMatches) {
      cancel(save: false);
      return;
    }
    step = value;
    _changed();
    unawaited(_save('in_progress', value));
  }

  Future<void> _save(String status, int value) async {
    if (!ownerMatches) return;
    try {
      await _repository?.saveProgress(
        VendorGuideProgress(status: status, step: value),
      );
    } catch (_) {
      /* Guide metadata must not block the app. */
    }
  }

  Future<void> next() async {
    if (!active || busy || !canContinue) return;
    if (!ownerMatches) {
      cancel(save: false);
      return;
    }
    busy = true;
    _changed();
    final desired = step == 3 ? 2 : 3;
    try {
      await navigation.select(desired);
      if (!active || !ownerMatches || navigation.index != desired) return;
      if (step == 5) {
        active = false;
        ++_generation;
        unawaited(_save('completed', 6));
      } else {
        _advance(step + 1);
      }
    } finally {
      busy = false;
      _changed();
    }
  }

  Future<void> back() async {
    if (!active || busy) return;
    if (step == 0) {
      cancel();
      return;
    }
    busy = true;
    _changed();
    final previous = step <= 1
        ? 0
        : step <= 4
        ? 1
        : 4;
    final index = previous == 0
        ? 0
        : previous == 1
        ? 1
        : 2;
    try {
      await navigation.select(index);
      if (active && navigation.index == index) {
        step = previous;
        _changed();
      }
    } finally {
      busy = false;
      _changed();
    }
  }

  void reconcile() {
    if (!active) return;
    if (!navigation.active || !ownerMatches) {
      cancel(save: false);
      return;
    }
    if (step == 4 && calendarOpened && target(TourTargets.calendar) != null) {
      calendarOpened = false;
      _changed();
    }
    // Do not infer a cancelled action while a menu is reversing: its route
    // disappears before the selected action opens the real business form.
  }

  void cancel({bool save = true}) {
    if (save && active) unawaited(_save('skipped', step));
    active = false;
    busy = false;
    ++_generation;
    _changed();
  }

  void _changed() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      notifyListeners();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}
