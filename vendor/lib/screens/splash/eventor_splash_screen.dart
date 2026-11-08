import 'package:flutter/material.dart';

class EventorSplashScreen extends StatefulWidget {
  final Widget nextScreen;
  const EventorSplashScreen({super.key, required this.nextScreen});
  @override
  State<EventorSplashScreen> createState() => _EventorSplashScreenState();
}

class _EventorSplashScreenState extends State<EventorSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _showNextScreen = false;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _showNextScreen = true);
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showNextScreen) return widget.nextScreen;
    return Scaffold(
      backgroundColor: const Color(0xFF80152C),
      body: SizedBox.expand(
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: _controller,
            curve: const Interval(0, .2, curve: Curves.easeOut),
          ),
          child: Image.asset(
            'assets/splash/eventor_splash.png',
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const Center(
              child: Text(
                'EVENTOR',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFCB48),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
