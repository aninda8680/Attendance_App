import 'package:flutter/material.dart';

class AnimatedActionButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;
  final Duration delay;
  final Color? backgroundColor;

  const AnimatedActionButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.delay = Duration.zero,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 20.0, end: 0.0), // slides upward
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, val, _) {
        final opacity = (1 - (val / 20)).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, val),
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: backgroundColor,
              ),
              onPressed: onPressed,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
