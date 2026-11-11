import 'package:flutter/material.dart';

import '../../services/vendor_tour_controller.dart';

/// Registers a real control without changing its appearance or callback.
class TourAnchor extends StatefulWidget {
  const TourAnchor({
    super.key,
    required this.id,
    required this.child,
    this.controller,
  });
  final String id;
  final Widget child;
  final VendorTourController? controller;
  @override
  State<TourAnchor> createState() => _TourAnchorState();
}

class _TourAnchorState extends State<TourAnchor> {
  final _key = GlobalKey();
  VendorTourController get controller =>
      widget.controller ?? VendorTourController.instance;
  @override
  void initState() {
    super.initState();
    controller.register(widget.id, this, _key);
  }

  @override
  void didUpdateWidget(TourAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id ||
        oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? VendorTourController.instance).unregister(
        oldWidget.id,
        this,
      );
      controller.register(widget.id, this, _key);
    }
  }

  @override
  void dispose() {
    controller.unregister(widget.id, this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SizedBox(key: _key, child: widget.child);
}
