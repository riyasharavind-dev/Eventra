import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/vendor_tour_controller.dart';
import 'tour_instruction_card.dart';

/// A visual cutout with four hit-test barriers. The hole forwards touches to the
/// original app control; no duplicate button or synthetic tap is used.
class VendorTourLayer extends StatefulWidget {
  const VendorTourLayer({super.key, this.controller});
  final VendorTourController? controller;
  @override
  State<VendorTourLayer> createState() => _VendorTourLayerState();
}

class _VendorTourLayerState extends State<VendorTourLayer> {
  final _surface = GlobalKey();
  VendorTourController get tour =>
      widget.controller ?? VendorTourController.instance;
  Timer? _timer;
  Rect? _rect;
  GlobalKey? _lastKey;
  bool _scrolling = false;
  @override
  void initState() {
    super.initState();
    tour.addListener(_changed);
  }

  void _changed() {
    if (tour.active) {
      _timer ??= Timer.periodic(
        const Duration(milliseconds: 90),
        (_) => _measure(),
      );
    } else {
      _timer?.cancel();
      _timer = null;
      _rect = null;
      _lastKey = null;
    }
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
  }

  void _measure() {
    if (!mounted || !tour.active) return;
    tour.reconcile();
    if (!tour.active) return;
    final key = tour.target(tour.targetId);
    final box = key?.currentContext?.findRenderObject();
    final surface = _surface.currentContext?.findRenderObject();
    Rect? rect;
    if (box is RenderBox &&
        surface is RenderBox &&
        box.attached &&
        surface.attached &&
        box.hasSize &&
        surface.hasSize) {
      rect = (surface.globalToLocal(box.localToGlobal(Offset.zero)) & box.size)
          .inflate(5)
          .intersect(Offset.zero & surface.size);
      if (rect.isEmpty) rect = null;
      if ((key != _lastKey || rect == null) && !_scrolling) {
        _lastKey = key;
        final context = key!.currentContext!;
        if (Scrollable.maybeOf(context) != null) {
          _scrolling = true;
          unawaited(
            Scrollable.ensureVisible(
              context,
              alignment: .25,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            ).whenComplete(() => _scrolling = false),
          );
        }
      }
    }
    if (rect != _rect && mounted) setState(() => _rect = rect);
  }

  @override
  void dispose() {
    _timer?.cancel();
    tour.removeListener(_changed);
    super.dispose();
  }

  Widget _barrier(Rect rect) => Positioned.fromRect(
    rect: rect,
    child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () {}),
  );
  @override
  Widget build(BuildContext context) {
    if (!tour.active) return const SizedBox.shrink();
    // Native dropdowns/dialogs must receive their own normal interactions.
    if (tour.navigation.modalOpen && tour.step != 2) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final full = Offset.zero & size;
          final hole = (_rect ?? Rect.zero).intersect(full);
          final safe = MediaQuery.paddingOf(context);
          final height = math
              .min(
                size.height - safe.top - safe.bottom - 24,
                180 +
                    math.max(
                          0,
                          MediaQuery.textScalerOf(context).scale(12) - 12,
                        ) *
                        5,
              )
              .toDouble();
          final width = math.min(330.0, size.width - 28);
          final preferred = _rect == null
              ? size.height - height - safe.bottom - 120
              : hole.top > size.height * .5
              ? hole.top - height - 14
              : hole.bottom + 14;
          final top = preferred
              .clamp(
                safe.top + 10,
                math.max(
                  safe.top + 10,
                  size.height - safe.bottom - height - 12,
                ),
              )
              .toDouble();
          final left = ((_rect?.center.dx ?? size.width / 2) - width / 2)
              .clamp(14.0, math.max(14.0, size.width - width - 14))
              .toDouble();
          return SizedBox.expand(
            key: _surface,
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _LiveSpotlight(_rect)),
                  ),
                ),
                if (_rect == null || tour.busy)
                  _barrier(full)
                else ...[
                  _barrier(Rect.fromLTRB(0, 0, size.width, hole.top)),
                  _barrier(
                    Rect.fromLTRB(0, hole.bottom, size.width, size.height),
                  ),
                  _barrier(Rect.fromLTRB(0, hole.top, hole.left, hole.bottom)),
                  _barrier(
                    Rect.fromLTRB(
                      hole.right,
                      hole.top,
                      size.width,
                      hole.bottom,
                    ),
                  ),
                ],
                Positioned(
                  left: left,
                  top: top,
                  width: width,
                  height: height,
                  child: TourMiniTipCard(
                    controller: tour,
                    waiting: _rect == null,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LiveSpotlight extends CustomPainter {
  _LiveSpotlight(this.rect);
  final Rect? rect;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    if (rect != null) {
      path.addRRect(RRect.fromRectAndRadius(rect!, const Radius.circular(14)));
    }
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: .42));
    if (rect != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect!, const Radius.circular(14)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFFFCB48),
      );
    }
  }

  @override
  bool shouldRepaint(_LiveSpotlight old) => old.rect != rect;
}
