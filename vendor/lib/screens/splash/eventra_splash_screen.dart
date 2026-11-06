
import 'package:flutter/material.dart';

class EventraSplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const EventraSplashScreen({
    super.key,
    required this.nextScreen,
  });

  @override
  State<EventraSplashScreen> createState() =>
      _EventraSplashScreenState();
}

class _EventraSplashScreenState extends State<EventraSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _showNextScreen = false;

  final List<String> _frames = List.generate(
    19,
    (index) =>
        'assets/splash/Splash ${(index + 1).toString().padLeft(2, '0')}.png',
  );

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _showNextScreen = true;
        });
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
    if (_showNextScreen) {
      return widget.nextScreen;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox.expand(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final frameIndex = (_controller.value * _frames.length)
                .floor()
                .clamp(0, _frames.length - 1);

            return Image.asset(
              _frames[frameIndex],
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) {
                debugPrint(
                  'Eventra splash asset failed: '
                  '${_frames[frameIndex]} — $error',
                );

                return const Center(
                  child: Text(
                    'EVENTRA',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF59000D),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
