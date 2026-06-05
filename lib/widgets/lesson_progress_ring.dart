import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';

class LessonProgressRing extends StatelessWidget {
  const LessonProgressRing({
    super.key,
    required this.percent,
    required this.tapped,
    required this.total,
    required this.theme,
    required this.lang,
    this.size = 108,
    this.strokeWidth = 12,
  });

  final int percent;
  final int tapped;
  final int total;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final progress = (percent / 100).clamp(0.0, 1.0);
    final accent = theme.bgAccent;
    final track = accent.withValues(alpha: 0.18);
    final fractionLabel = total > 0
        ? AppStrings.wordsTappedFraction(tapped, total, lang)
        : AppStrings.wordsTappedFraction(0, 0, lang);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LessonProgressRingPainter(
          progress: progress,
          accent: accent,
          track: track,
          strokeWidth: strokeWidth,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent%',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: accent,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                fractionLabel,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: theme.textMain.withValues(alpha: 0.55),
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonProgressRingPainter extends CustomPainter {
  _LessonProgressRingPainter({
    required this.progress,
    required this.accent,
    required this.track,
    required this.strokeWidth,
  });

  final double progress;
  final Color accent;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LessonProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accent != accent ||
        oldDelegate.track != track;
  }
}
