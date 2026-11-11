import 'package:eventor_vendor/services/app_settings_controller.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppShimmer extends StatefulWidget {
  const AppShimmer({super.key, required this.child, this.color});
  final Widget child;
  final Color? color;
  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1350),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base =
        widget.color?.withValues(alpha: 0.35) ?? const Color(0xFFE7E7EC);
    final highlight =
        widget.color?.withValues(alpha: 0.85) ?? const Color(0xFFF8F8FA);
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          child: widget.child,
          builder: (context, child) => ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) {
              final offset = MediaQuery.disableAnimationsOf(context)
                  ? 0.0
                  : _controller.value * 4 - 2;
              return LinearGradient(
                begin: Alignment(offset - 1, -0.3),
                end: Alignment(offset + 1, 0.3),
                colors: [base, highlight, base],
                stops: const [0.2, 0.5, 0.8],
              ).createShader(bounds);
            },
            child: child,
          ),
        ),
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 10,
  });
  final double? width;
  final double height, radius;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Compact shimmer for pending actions, fitted to the existing button/icon slot.
class AppShimmerIndicator extends StatelessWidget {
  const AppShimmerIndicator({super.key, this.color, this.strokeWidth = 2});
  final Color? color;
  final double strokeWidth;
  @override
  Widget build(BuildContext context) => Semantics(
    label: AppSettingsScope.translate(context, "vendor.loading.dc380888"),
    liveRegion: true,
    child: SizedBox(
      width: 26,
      height: 20,
      child: AppShimmer(
        color: color ?? const Color(0xFF80152C),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) SizedBox(width: strokeWidth.clamp(1, 3)),
              Expanded(
                child: FractionallySizedBox(
                  heightFactor: [0.5, 0.95, 0.7][i],
                  child: const SkeletonBox(height: 18, radius: 3),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class ShimmerLoadingBar extends StatelessWidget {
  const ShimmerLoadingBar({super.key, this.color, this.minHeight = 4});
  final Color? color;
  final double minHeight;
  @override
  Widget build(BuildContext context) => Semantics(
    label: AppSettingsScope.translate(context, "vendor.loading.dc380888"),
    liveRegion: true,
    child: AppShimmer(
      color: color ?? const Color(0xFF80152C),
      child: SkeletonBox(
        width: double.infinity,
        height: math.max(minHeight, 3),
        radius: 3,
      ),
    ),
  );
}

enum SkeletonLayout {
  dashboard,
  profile,
  listings,
  bookings,
  form,
  document,
  calendar,
}

class AppContentSkeleton extends StatelessWidget {
  const AppContentSkeleton({
    super.key,
    this.layout = SkeletonLayout.listings,
    this.rows = 4,
    this.bottomPadding = 128,
  });
  final SkeletonLayout layout;
  final int rows;
  final double bottomPadding;
  Widget _line(double fraction, {double height = 12}) => FractionallySizedBox(
    widthFactor: fraction,
    child: SkeletonBox(height: height, radius: 5),
  );
  Widget _lines() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _line(0.8),
      const SizedBox(height: 10),
      _line(0.58),
      const SizedBox(height: 14),
      _line(0.4, height: 17),
    ],
  );
  Widget _row() => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.white),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const SkeletonBox(width: 76, height: 88, radius: 12),
        const SizedBox(width: 14),
        Expanded(child: _lines()),
      ],
    ),
  );
  Widget _stats() => Row(
    children: [
      for (var i = 0; i < 3; i++) ...[
        if (i > 0) const SizedBox(width: 12),
        const Expanded(child: SkeletonBox(height: 70, radius: 12)),
      ],
    ],
  );
  @override
  Widget build(BuildContext context) => Semantics(
    label: AppSettingsScope.translate(
      context,
      "vendor.loading_content.d1049c5e",
    ),
    liveRegion: true,
    child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(18, 20, 18, bottomPadding),
      child: AppShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (layout == SkeletonLayout.dashboard) ...[
              Row(
                children: [
                  const SkeletonBox(width: 50, height: 50, radius: 25),
                  const SizedBox(width: 12),
                  Expanded(child: _lines()),
                ],
              ),
              const SizedBox(height: 22),
              const SkeletonBox(
                width: double.infinity,
                height: 130,
                radius: 20,
              ),
              const SizedBox(height: 18),
              _stats(),
              const SizedBox(height: 24),
            ],
            if (layout == SkeletonLayout.profile) ...[
              Row(
                children: [
                  const SkeletonBox(width: 78, height: 78, radius: 39),
                  const SizedBox(width: 16),
                  Expanded(child: _lines()),
                ],
              ),
              const SizedBox(height: 24),
              _stats(),
              const SizedBox(height: 24),
            ],
            if (layout == SkeletonLayout.form) ...[
              const SkeletonBox(
                width: double.infinity,
                height: 128,
                radius: 18,
              ),
              const SizedBox(height: 24),
              for (var i = 0; i < 5; i++) ...[
                _line(0.35),
                const SizedBox(height: 10),
                const SkeletonBox(width: double.infinity, height: 50),
                const SizedBox(height: 22),
              ],
            ] else if (layout == SkeletonLayout.document) ...[
              _line(0.65, height: 24),
              const SizedBox(height: 20),
              for (var i = 0; i < 5; i++) ...[
                _line(0.94),
                const SizedBox(height: 10),
                _line(1),
                const SizedBox(height: 10),
                _line(0.75),
                const SizedBox(height: 24),
              ],
            ] else if (layout == SkeletonLayout.calendar) ...[
              Center(child: SizedBox(width: 130, child: _line(1, height: 20))),
              const SizedBox(height: 22),
              for (var row = 0; row < 5; row++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(
                      7,
                      (_) =>
                          const SkeletonBox(width: 24, height: 24, radius: 12),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              for (var i = 0; i < 2; i++) _row(),
            ] else ...[
              _line(0.48, height: 18),
              const SizedBox(height: 18),
              for (var i = 0; i < rows; i++) _row(),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Keeps the pull-to-refresh gesture with a shimmer bar instead of a spinner.
class AppShimmerRefreshIndicator extends StatefulWidget {
  const AppShimmerRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.loading = false,
    this.skeletonLayout = SkeletonLayout.listings,
    this.color,
  });
  final Widget child;
  final RefreshCallback onRefresh;
  final bool loading;
  final SkeletonLayout skeletonLayout;
  final Color? color;
  @override
  State<AppShimmerRefreshIndicator> createState() =>
      _AppShimmerRefreshIndicatorState();
}

class _AppShimmerRefreshIndicatorState
    extends State<AppShimmerRefreshIndicator> {
  bool _visible = false;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      RefreshIndicator.noSpinner(
        onRefresh: widget.onRefresh,
        triggerMode: RefreshIndicatorTriggerMode.onEdge,
        notificationPredicate: (notification) =>
            notification.depth == 0 &&
            notification.metrics.axisDirection == AxisDirection.down,
        onStatusChange: (status) {
          final visible =
              // A drag starts before there is a meaningful downward pull.
              // Keep taps, focus changes and small scrolls visually idle.
              status == RefreshIndicatorStatus.armed ||
              status == RefreshIndicatorStatus.snap ||
              status == RefreshIndicatorStatus.refresh;
          if (mounted && visible != _visible) {
            setState(() => _visible = visible);
          }
        },
        child: widget.child,
      ),
      // Overlay rather than replace the content, preserving search/form state.
      if (widget.loading)
        Positioned.fill(
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: AppContentSkeleton(layout: widget.skeletonLayout),
          ),
        ),
      if (_visible)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(child: ShimmerLoadingBar(color: widget.color)),
        ),
    ],
  );
}
