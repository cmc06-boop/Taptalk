import 'package:flutter/material.dart';

abstract final class TapTalkBrandAssets {
  static const logoIcon = 'assets/images/Logo/Logo Icon.png';
  static const textIcon = 'assets/images/Logo/Text Icon.png';
  static const fullLogo = 'assets/images/Logo/Full logo.png';
}

/// App mark from [assets/images/Logo/Logo Icon.png] — square crop over a
/// separate blurred glow circle.
class TapTalkLogo extends StatelessWidget {
  const TapTalkLogo({super.key, this.size = 100});

  final double size;

  @override
  Widget build(BuildContext context) {
    final glowSize = size * 1.06;
    final radius = size * 0.18;

    return SizedBox(
      width: glowSize,
      height: glowSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: glowSize,
            height: glowSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF3ECF8E).withValues(alpha: 0.55),
                  const Color(0xFF7CFF6B).withValues(alpha: 0.32),
                  const Color(0xFF5BB88A).withValues(alpha: 0.12),
                  const Color(0xFFB3E6CC).withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.32, 0.62, 1],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3ECF8E).withValues(alpha: 0.28),
                  blurRadius: 14,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Image.asset(
              TapTalkBrandAssets.logoIcon,
              width: size,
              height: size,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
        ],
      ),
    );
  }
}

/// Wordmark from [assets/images/Logo/Text Icon.png].
class TapTalkWordmark extends StatelessWidget {
  const TapTalkWordmark({
    super.key,
    this.height = 44,
    this.maxWidth = 220,
  });

  final double height;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: height),
      child: Image.asset(
        TapTalkBrandAssets.textIcon,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

/// Compact wordmark for the app header bar.
class TapTalkHeaderWordmark extends StatelessWidget {
  const TapTalkHeaderWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -16),
      child: const TapTalkWordmark(height: 72, maxWidth: 340),
    );
  }
}

/// Combined icon + wordmark from [assets/images/Logo/Full logo.png].
class TapTalkFullLogo extends StatelessWidget {
  const TapTalkFullLogo({
    super.key,
    this.width = 240,
  });

  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      TapTalkBrandAssets.fullLogo,
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
