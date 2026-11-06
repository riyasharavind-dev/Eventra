import 'app_shimmer.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

class FloatingMenuAction {
  const FloatingMenuAction({
    required this.label,
    required this.icon,
    required this.onSelected,
  });
  final String label;
  final IconData icon;
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
      selected = await showGeneralDialog<int>(
        context: context,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(context)
            .modalBarrierDismissLabel,
        barrierColor: Colors.transparent,
        transitionDuration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 240),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SizedBox.shrink(),
        transitionBuilder: (context, animation, secondaryAnimation, child) =>
            Stack(
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
                          final start =
                              (actions.length - 1 - index) /
                              actions.length *
                              0.35;
                          final progress = Curves.easeOutCubic.transform(
                            ((animation.value - start) / (1 - start)).clamp(
                              0.0,
                              1.0,
                            ),
                          );
                          return Opacity(
                            opacity: progress,
                            child: Transform.translate(
                              offset: Offset(0, 14 * (1 - progress)),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Material(
                                  color: Colors.white,
                                  elevation: 5,
                                  shadowColor: const Color(0x33000000),
                                  borderRadius: BorderRadius.circular(12),
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
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            action.icon,
                                            color: widget.color,
                                            size: 21,
                                          ),
                                          const SizedBox(width: 12),
                                          Flexible(
                                            child: Text(
                                              action.label,
                                              style: const TextStyle(
                                                color: Color(0xFF282837),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
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
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      );
    } finally {
      if (mounted) setState(() => open = false);
    }
    if (mounted && selected != null) await actions[selected].onSelected();
  }

  @override
  Widget build(BuildContext context) => FloatingActionButton(
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
                : const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: const Icon(Icons.add_rounded, size: 30),
          ),
  );
}
