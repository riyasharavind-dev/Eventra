import 'package:flutter/material.dart';

class VendorNavigationController extends ChangeNotifier {
  static final instance = VendorNavigationController();
  static const guideRouteName = '/vendor/trial';
  static const floatingActionsRouteName = '/vendor/listings/actions';
  final navigatorKey = GlobalKey<NavigatorState>();
  late final NavigatorObserver observer = _VendorRouteObserver(this);
  final List<Route<dynamic>> _routes = [];
  Object? _owner;
  ValueChanged<int>? _select;
  int index = 0;
  bool _scheduled = false, _switching = false;
  bool get active => _owner != null;
  // The lightweight + menu leaves navigation available. Blocking dialogs,
  // confirmation sheets and other popup routes retain their modal behavior.
  bool get modalOpen =>
      _routes.any((route) => route.settings.name == guideRouteName) ||
      _routes.isNotEmpty &&
          _routes.last is PopupRoute &&
          _routes.last.settings.name != floatingActionsRouteName;
  void attach(Object owner, ValueChanged<int> select, {int selected = 0}) {
    _owner = owner;
    _select = select;
    index = selected;
    _changed();
  }

  void detach(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _select = null;
    _changed();
    // Sign-out/role-gate removal must also remove any private detail routes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!active) {
        navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
    });
  }

  void setIndex(int value) {
    if (index != value) {
      index = value;
      _changed();
    }
  }

  Future<void> select(int value) async {
    if (!active || _switching || modalOpen || value < 0 || value > 3) return;
    _switching = true;
    try {
      final navigator = navigatorKey.currentState;
      while (navigator != null && navigator.canPop()) {
        final top = _routes.isEmpty ? null : _routes.last;
        if (top?.popDisposition == RoutePopDisposition.doNotPop) {
          // Honor existing save/discard and in-flight operation guards.
          await navigator.maybePop();
          return;
        }
        final popped = await navigator.maybePop();
        if (!popped || (_routes.isNotEmpty && identical(_routes.last, top))) {
          return;
        }
      }
      _select?.call(value);
    } finally {
      _switching = false;
    }
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

class _VendorRouteObserver extends NavigatorObserver {
  final VendorNavigationController controller;
  _VendorRouteObserver(this.controller);
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null) {
      controller._routes.clear();
    }
    controller._routes.add(route);
    controller._changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    controller._routes.remove(route);
    controller._changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    controller._routes.remove(route);
    controller._changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : controller._routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        controller._routes.removeAt(index);
      } else {
        controller._routes[index] = newRoute;
      }
    } else if (newRoute != null) {
      controller._routes.add(newRoute);
    }
    controller._changed();
  }
}
