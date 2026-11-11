import 'package:eventor_vendor/services/vendor_tour_controller.dart';
import 'package:eventor_vendor/widgets/trial/tour_anchor.dart';
import 'package:eventor_vendor/core/theme/app_icon_colors.dart';

import '../../services/vendor_navigation_controller.dart';
import 'app_shimmer.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

class FloatingMenuAction {
  const FloatingMenuAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.tourId,
  });
  final String label;
  final IconData icon;
  final String? tourId;
  final Future<void> Function() onSelected;
}

/// Small action boards above the existing floating button.
class ExpandableActionButton extends StatefulWidget {
  const ExpandableActionButton({
    super.key,
    required this.actions,
    required this.color,
    this.busy = false,
    required this.tooltip,
  });
  final List<FloatingMenuAction> actions;
  final Color color;
  final bool busy;
  final String tooltip;
  @override
  State<ExpandableActionButton> createState() => _ExpandableActionButtonState();
}

class _ExpandableActionButtonState extends State<ExpandableActionButton> {
  bool open = false;
  final anchor = GlobalKey();

  Future<void> toggle() async {
    if (open || widget.busy || widget.actions.isEmpty) return;
    final box = anchor.currentContext!.findRenderObject()! as RenderBox;
    final navigator = Navigator.of(context, rootNavigator: true);
    final overlayBox =
        navigator.overlay!.context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    final right = math.max(
      16.0,
      overlayBox.size.width - origin.dx - box.size.width,
    );
    final bottom = overlayBox.size.height - origin.dy + 12;
    final maxHeight = math.max(
      0.0,
      origin.dy - MediaQuery.paddingOf(context).top - 20,
    );
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final actions = List<FloatingMenuAction>.of(widget.actions);
    setState(() => open = true);
    int? selected;
    bool choosing = false;
    try {
      final route = RawDialogRoute<int>(
        settings: const RouteSettings(
          name: VendorNavigationController.floatingActionsRouteName,
        ),
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(context)
            .modalBarrierDismissLabel,
        barrierColor: Colors.transparent,
        transitionDuration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 520),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SizedBox.shrink(),
        transitionBuilder: (context, animation, secondaryAnimation, child) =>
            AnimatedBuilder(
              animation: animation,
              builder: (context, _) => Stack(
                children: [
                  Positioned(
                    right: right,
                    bottom: bottom,
                    width: math.min(240, overlayBox.size.width - 32),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxHeight),
                      child: SingleChildScrollView(
                        reverse: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(actions.length, (index) {
                            final action = actions[index];
                            // The board closest to the button appears first.
                            final rank = actions.length - 1 - index;
                            final start = actions.length <= 1
                                ? 0.0
                                : rank / (actions.length - 1) * 0.22;
                            final progress = Curves.easeInOutSine.transform(
                              ((animation.value - start) / (1 - start)).clamp(
                                0.0,
                                1.0,
                              ),
                            );
                            return TourAnchor(
                              id: action.tourId ?? 'menu-action-$index',
                              child: IgnorePointer(
                                ignoring:
                                    progress < 0.85 ||
                                    animation.status == AnimationStatus.reverse,
                                child: Opacity(
                                  opacity: progress,
                                  child: Transform.translate(
                                    offset: Offset(
                                      0,
                                      (64.0 + rank * 62) * (1 - progress),
                                    ),
                                    child: Transform.scale(
                                      scale: 0.88 + 0.12 * progress,
                                      alignment: Alignment.bottomRight,
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFF0EDF0),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF80152C)
                                                    .withValues(alpha: 0.08),
                                                blurRadius: 14,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: InkWell(
                                              onTap: () {
                                                if (choosing) {
                                                  return;
                                                }
                                                choosing = true;
                                                Navigator.pop(context, index);
                                              },
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 14,
                                                    ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      action.icon,
                                                      color: AppIconColors
                                                          .standard,
                                                      size: 21,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Flexible(
                                                      child: Text(
                                                        action.label,
                                                        style: const TextStyle(
                                                          color: Color(
                                                            0xFF282837,
                                                          ),
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      );
      VendorTourController.instance.menuOpened();
      selected = await navigator.push<int>(route);
      // Let the boards finish closing before opening an editor screen.
      await route.completed;
    } finally {
      if (mounted) setState(() => open = false);
    }
    if (mounted && selected != null) await actions[selected].onSelected();
  }

  @override
  Widget build(BuildContext context) => TourAnchor(
    id: TourTargets.add,
    child: FloatingActionButton(
      key: anchor,
      heroTag: 'vendor-listings-add',
      tooltip: widget.tooltip,
      onPressed: widget.busy ? null : toggle,
      backgroundColor: widget.color,
      foregroundColor: Colors.white,
      child: widget.busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: AppShimmerIndicator(strokeWidth: 2, color: Colors.white),
            )
          : AnimatedRotation(
              turns: open ? 0.125 : 0,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubicEmphasized,
              child: const Icon(Icons.add_rounded, size: 30),
            ),
    ),
  );
}
