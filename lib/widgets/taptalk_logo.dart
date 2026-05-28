import 'package:flutter/material.dart';

/// Circular logo matching the web prototype (black circle + green glow).
class TapTalkLogo extends StatelessWidget {
  const TapTalkLogo({super.key, this.size = 100});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5BB88A).withValues(alpha: 0.48),
            blurRadius: 28,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: const Color(0xFFB3E6CC).withValues(alpha: 0.45),
            blurRadius: 42,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.record_voice_over_rounded,
          color: const Color(0xFF8EE66B),
          size: size * 0.5,
        ),
      ),
    );
  }
}
