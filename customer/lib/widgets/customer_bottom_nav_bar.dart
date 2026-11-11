import 'package:flutter/material.dart';
import '../core/theme/app_icon_colors.dart';
import '../services/app_settings_controller.dart';

class CustomerBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomerBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _wine = Color(0xFF80152C);
  static const _wineDark = Color(0xFF650C20);
  static const inactiveIconColor = AppIconColors.standard;

  static const _labels = ['Home', 'Explore', 'Bookings', 'Me'];
  static const _tamilLabels = ['முகப்பு', 'ஆராய்', 'முன்பதிவு', 'சுயவிவரம்'];

  static const _icons = [
    Icons.home_outlined,
    Icons.explore_outlined,
    Icons.calendar_month_outlined,
    Icons.person_rounded,
  ];

  static const _duration = Duration(milliseconds: 440);
  static const _curve = Curves.easeInOutCubicEmphasized;

  @override
  Widget build(BuildContext context) {
    final count = _labels.length;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      duration: reduceMotion ? Duration.zero : _duration,
      curve: _curve,
      tween: Tween<double>(
        begin: currentIndex.toDouble(),
        end: currentIndex.toDouble(),
      ),
      builder: (context, position, child) {
        final alignX = -1.0 + (2.0 * position / (count - 1));
        return SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            height: 74,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(29),
              border: Border.all(color: const Color(0xFFF0EDF0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 24,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Sliding red indicator
                Align(
                  alignment: Alignment(alignX, 0),
                  child: FractionallySizedBox(
                    widthFactor: 1 / count,
                    heightFactor: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_wine, _wineDark],
                        ),
                        borderRadius: BorderRadius.circular(23),
                      ),
                    ),
                  ),
                ),

                // Tab items
                Row(
                  children: List.generate(count, (index) {
                    final selected = currentIndex == index;
                    // Match the foreground to the moving highlight, including rapid taps.
                    final emphasis = (1.0 - (position - index).abs()).clamp(
                      0.0,
                      1.0,
                    );
                    final foreground = Color.lerp(
                      inactiveIconColor,
                      Colors.white,
                      emphasis,
                    )!;

                    final label = AppSettingsScope.of(context).text(
                      _labels[index],
                      _tamilLabels[index],
                    );

                    return Expanded(
                      child: Semantics(
                        label: label,
                        button: true,
                        selected: selected,
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(23),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => onTap(index),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Transform.translate(
                                    offset: Offset(0, -2 * emphasis),
                                    child: Transform.scale(
                                      scale: 1 + (2 / 23) * emphasis,
                                      child: Icon(
                                        _icons[index],
                                        size: 23,
                                        color: foreground,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  DefaultTextStyle(
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      height: 1.2,
                                      fontWeight: FontWeight.lerp(
                                        FontWeight.w400,
                                        FontWeight.w600,
                                        emphasis,
                                      ),
                                      color: foreground,
                                    ),
                                    child: Text(
                                      label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
