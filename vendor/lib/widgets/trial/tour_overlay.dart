import 'package:flutter/material.dart';

/// Dims only the safe preview; the highlighted control retains its real tap.
class TourOverlay extends StatefulWidget {
  const TourOverlay({super.key, required this.targetKey, required this.child});
  final GlobalKey targetKey;
  final Widget child;
  @override
  State<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<TourOverlay> {
  Rect? _target;
  void _measure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = widget.targetKey.currentContext?.findRenderObject();
      final box = context.findRenderObject();
      if (target is! RenderBox ||
          box is! RenderBox ||
          !target.hasSize ||
          !box.hasSize) {
        return;
      }
      final rect =
          (target.localToGlobal(Offset.zero, ancestor: box) & target.size)
              .inflate(5);
      if (rect != _target) setState(() => _target = rect);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _measure();
  }

  @override
  void didUpdateWidget(TourOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _measure();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      widget.child,
      if (_target != null)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _Spotlight(_target!)),
          ),
        ),
    ],
  );
}

class _Spotlight extends CustomPainter {
  _Spotlight(this.target);
  final Rect target;
  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(target, const Radius.circular(15));
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(hole);
    canvas.drawPath(mask, Paint()..color = Colors.black.withValues(alpha: .30));
    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFFCB48),
    );
  }

  @override
  bool shouldRepaint(_Spotlight oldDelegate) => target != oldDelegate.target;
}
