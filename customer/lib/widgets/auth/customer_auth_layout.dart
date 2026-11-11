import 'package:flutter/material.dart';

import '../../services/app_settings_controller.dart';

const authWine = Color(0xFF80152C);
String authText(BuildContext context, String en, String ta) {
  final scope = context.dependOnInheritedWidgetOfExactType<AppSettingsScope>();
  return scope?.notifier?.text(en, ta) ?? en;
}

class EventorAuthBrand extends StatelessWidget {
  const EventorAuthBrand({super.key});
  @override
  Widget build(BuildContext context) => const Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.celebration_rounded, color: authWine, size: 22),
      Text(
        'Eventor',
        style: TextStyle(
          color: authWine,
          fontSize: 29,
          fontWeight: FontWeight.w900,
          letterSpacing: -.8,
        ),
      ),
    ],
  );
}

class AuthHeroIcon extends StatelessWidget {
  const AuthHeroIcon({super.key, this.signup = false, this.compact = false});
  final bool signup, compact;
  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: compact ? 78 : 104,
      height: compact ? 68 : 78,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 4,
            right: 4,
            bottom: 2,
            top: 15,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF5E8EC),
                borderRadius: BorderRadius.circular(26),
              ),
            ),
          ),
          Icon(
            signup
                ? Icons.person_add_alt_1_outlined
                : Icons.phone_iphone_outlined,
            size: compact ? 48 : 55,
            color: authWine,
          ),
          Positioned(
            right: compact ? 8 : 17,
            bottom: 5,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: authWine,
                shape: BoxShape.circle,
              ),
              child: Icon(
                signup ? Icons.add : Icons.lock_outline,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class CustomerAuthLayout extends StatelessWidget {
  const CustomerAuthLayout({
    super.key,
    required this.child,
    this.onBack,
    this.showBack = true,
  });
  final Widget child;
  final bool showBack;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F8FA),
    body: Stack(
      children: [
        const Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _AuthWaves())),
        ),
        SafeArea(
          child: Column(
            children: [
              if (showBack)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: authText(context, 'Back', 'திரும்பு'),
                    onPressed: onBack ?? () => Navigator.maybePop(context),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: authWine,
                      size: 23,
                    ),
                  ),
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(26, 0, 26, 30),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 390),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AuthWaves extends CustomPainter {
  const _AuthWaves();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFFFBE1EB);
    final path = Path()
      ..moveTo(0, size.height * .88)
      ..cubicTo(
        size.width * .3,
        size.height * .72,
        size.width * .57,
        size.height * 1.03,
        size.width,
        size.height * .88,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, p);
    p.color = const Color(0xFFF5CCDC).withValues(alpha: .55);
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * .94)
        ..cubicTo(
          size.width * .35,
          size.height * .84,
          size.width * .7,
          size.height * 1.02,
          size.width,
          size.height * .96,
        )
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close(),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

InputDecoration authField(String title, IconData icon, {Widget? suffix}) =>
    InputDecoration(
      hintText: title,
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF73737D)),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF73737D)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFF0EDF0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFF0EDF0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: authWine, width: 1.5),
      ),
    );
