import 'package:flutter/material.dart';

class CustomerBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomerBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  // ===========================================================================
  // COLORS
  // ===========================================================================

  static const Color primaryRed =
      Color(0xFF9F0101);

  static const Color selectedRed =
      Color(0xFF9F0101);

  static const Color lightRed =
      Color(0xFFFFE5E5);

  static const Color unselectedRed =
      Color(0xFF9F0101);

  static const Color backgroundWhite =
      Color(0xFFFFFFFF);

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16,
          0,
          16,
          12,
        ),
        child: Container(
          height: 66,

          // ===================================================================
          // WHITE FLOATING BACKGROUND
          // ===================================================================

          decoration: BoxDecoration(
            color: backgroundWhite,

            borderRadius:
                BorderRadius.circular(24),

            border: Border.all(
              color: primaryRed.withValues(
                alpha: 0.18,
              ),
              width: 0.8,
            ),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.12,
                ),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(
                  0,
                  7,
                ),
              ),

              BoxShadow(
                color: primaryRed.withValues(
                  alpha: 0.08,
                ),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(
                  0,
                  3,
                ),
              ),
            ],
          ),

          child: Row(
            children: [
              // ===============================================================
              // HOME
              // ===============================================================

              _buildItem(
                index: 0,
                icon: Icons.home_outlined,
                selectedIcon:
                    Icons.home_rounded,
                label: 'Home',
              ),

              // ===============================================================
              // DISCOVER
              // ===============================================================

              _buildItem(
                index: 1,
                icon:
                    Icons.explore_outlined,
                selectedIcon:
                    Icons.explore_rounded,
                label: 'Discover',
              ),

              // ===============================================================
              // BOOKINGS
              // ===============================================================

              _buildItem(
                index: 2,
                icon:
                    Icons.bookmark_border_rounded,
                selectedIcon:
                    Icons.bookmark_rounded,
                label: 'Bookings',
              ),

              // ===============================================================
              // ME
              // ===============================================================

              _buildItem(
                index: 3,
                icon:
                    Icons.person_outline_rounded,
                selectedIcon:
                    Icons.person_rounded,
                label: 'Me',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // NAVIGATION ITEM
  // ===========================================================================

  Widget _buildItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final bool selected =
        currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),

        borderRadius:
            BorderRadius.circular(20),

        splashColor:
            primaryRed.withValues(
          alpha: 0.08,
        ),

        highlightColor:
            primaryRed.withValues(
          alpha: 0.04,
        ),

        child: AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 220,
          ),

          curve:
              Curves.easeOutCubic,

          margin:
              const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 7,
          ),

          // =================================================================
          // SELECTED ITEM
          // =================================================================

          decoration: BoxDecoration(
            color: selected
                ? lightRed
                : Colors.transparent,

            borderRadius:
                BorderRadius.circular(18),

            border: selected
                ? Border.all(
                    color: primaryRed
                        .withValues(
                      alpha: 0.10,
                    ),
                    width: 0.6,
                  )
                : null,
          ),

          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,

            children: [
              // ===============================================================
              // ICON
              // ===============================================================

              AnimatedContainer(
                duration:
                    const Duration(
                  milliseconds: 220,
                ),

                curve:
                    Curves.easeOutCubic,

                width: selected
                    ? 32
                    : 28,

                height: selected
                    ? 32
                    : 28,

                decoration:
                    BoxDecoration(
                  color: selected
                      ? selectedRed
                      : Colors.transparent,

                  borderRadius:
                      BorderRadius.circular(
                    11,
                  ),
                ),

                child: Center(
                  child: Icon(
                    selected
                        ? selectedIcon
                        : icon,

                    size: selected
                        ? 19
                        : 21,

                    color: selected
                        ? Colors.white
                        : unselectedRed,
                  ),
                ),
              ),

              const SizedBox(
                height: 3,
              ),

              // ===============================================================
              // LABEL
              // ===============================================================

              AnimatedDefaultTextStyle(
                duration:
                    const Duration(
                  milliseconds: 180,
                ),

                style: TextStyle(
                  fontSize: 10.5,

                  fontWeight: selected
                      ? FontWeight.w700
                      : FontWeight.w500,

                  color: selected
                      ? primaryRed
                      : unselectedRed,
                ),

                child: Text(
                  label,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}