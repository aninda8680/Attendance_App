import 'package:flutter/material.dart';

class AttendanceLoading extends StatelessWidget {
  const AttendanceLoading({super.key});

  @override
  Widget build(BuildContext context) {
    // 🎨 Softer, calm gradient (bluish-lavender tone)
    const gradientColors = [
      Color.fromARGB(255, 255, 255, 255), // soft indigo-blue
      Color.fromARGB(255, 177, 216, 255), // pale lavender-blue
    ];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🏫 Animated Logo
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.9, end: 1.1),
              duration: const Duration(seconds: 2),
              curve: Curves.easeInOut,
              builder: (context, scale, _) {
                return Transform.scale(
                  scale: scale,
                  child: Image.asset(
                    'assets/icons/logo.png',
                    width: 90,
                    height: 90,
                    fit: BoxFit.contain,
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // 💬 Loading Text
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.3, end: 1),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeInOut,
              builder: (context, opacity, _) {
                return Opacity(
                  opacity: opacity,
                  child: const Text(
                    "Loading your attendance...",
                    style: TextStyle(
                      color: Color.fromARGB(255, 0, 0, 0),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // 🔄 Progress Indicator
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
