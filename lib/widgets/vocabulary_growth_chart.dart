import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../data/models/vocabulary_growth_summary.dart';

class VocabularyGrowthChart extends StatelessWidget {
  const VocabularyGrowthChart({
    super.key,
    required this.points,
    required this.theme,
    required this.lang,
    this.showCumulative = false,
  });

  final List<VocabularyGrowthPoint> points;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final bool showCumulative;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: Text(
            AppStrings.noVocabularyData(lang),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: theme.textMain.withValues(alpha: 0.65),
            ),
          ),
        ),
      );
    }

    final accent = theme.bgAccent;
    final chartSurface = Color.alphaBlend(
      accent.withValues(alpha: 0.07),
      Color.alphaBlend(
        Colors.white.withValues(alpha: 0.14),
        Color.lerp(theme.bgLight, theme.bgMid, 0.68)!,
      ),
    );

    final values = points
        .map((p) => showCumulative ? p.cumulativeWords.toDouble() : p.newWords.toDouble())
        .toList();
    final peak = values.fold<double>(0, math.max);
    final displayPeak = peak <= 0 ? 1.0 : peak;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 168,
          child: CustomPaint(
            painter: _VocabularyLinePainter(
              points: points,
              values: values,
              peak: displayPeak,
              accent: accent,
              labelColor: theme.textMain.withValues(alpha: 0.62),
              gridColor: theme.textMain.withValues(alpha: 0.10),
              fillColor: accent.withValues(alpha: 0.14),
              lineColor: accent,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: chartSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: accent),
              const SizedBox(width: 6),
              Text(
                showCumulative
                    ? (lang == AppLanguage.filipino
                        ? 'Kabuuang salita'
                        : 'Total learned')
                    : (lang == AppLanguage.filipino
                        ? 'Bagong salita'
                        : 'New words'),
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.textMain.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _VocabularyLinePainter extends CustomPainter {
  _VocabularyLinePainter({
    required this.points,
    required this.values,
    required this.peak,
    required this.accent,
    required this.labelColor,
    required this.gridColor,
    required this.fillColor,
    required this.lineColor,
  });

  final List<VocabularyGrowthPoint> points;
  final List<double> values;
  final double peak;
  final Color accent;
  final Color labelColor;
  final Color gridColor;
  final Color fillColor;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 28.0;
    const topPad = 8.0;
    const bottomPad = 26.0;
    const rightPad = 8.0;

    final chartHeight = size.height - topPad - bottomPad;
    final chartWidth = size.width - leftPad - rightPad;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var i = 0; i <= 2; i++) {
      final y = topPad + chartHeight * (i / 2);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
    }

    final yMax = peak.ceil();
    final yLabels = [yMax.toString(), (yMax / 2).ceil().toString(), '0'];
    for (var i = 0; i < 3; i++) {
      final y = topPad + chartHeight * (i / 2);
      final tp = TextPainter(
        text: TextSpan(
          text: yLabels[i],
          style: TextStyle(
            color: labelColor,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    final count = points.length;
    if (count < 2) return;

    final stepX = chartWidth / (count - 1);
    final coords = <Offset>[];
    for (var i = 0; i < count; i++) {
      final fraction = (values[i] / peak).clamp(0.0, 1.0);
      final x = leftPad + stepX * i;
      final y = topPad + chartHeight * (1 - fraction);
      coords.add(Offset(x, y));
    }

    final fillPath = Path()
      ..moveTo(coords.first.dx, topPad + chartHeight)
      ..lineTo(coords.first.dx, coords.first.dy);
    for (var i = 1; i < coords.length; i++) {
      final prev = coords[i - 1];
      final curr = coords[i];
      final midX = (prev.dx + curr.dx) / 2;
      fillPath.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
    }
    fillPath
      ..lineTo(coords.last.dx, topPad + chartHeight)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            fillColor,
            fillColor.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(leftPad, topPad, chartWidth, chartHeight)),
    );

    final linePath = Path()..moveTo(coords.first.dx, coords.first.dy);
    for (var i = 1; i < coords.length; i++) {
      final prev = coords[i - 1];
      final curr = coords[i];
      final midX = (prev.dx + curr.dx) / 2;
      linePath.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
    }

    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    for (final point in coords) {
      canvas.drawCircle(
        point,
        5.5,
        Paint()..color = accent.withValues(alpha: 0.22),
      );
      canvas.drawCircle(point, 3.2, Paint()..color = lineColor);
    }

    for (var i = 0; i < count; i++) {
      if (points[i].label.isEmpty) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: points[i].label,
          style: TextStyle(
            color: labelColor,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: stepX + 12);

      final x = leftPad + stepX * i;
      tp.paint(
        canvas,
        Offset(x - tp.width / 2, size.height - bottomPad + 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VocabularyLinePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.values != values ||
        oldDelegate.peak != peak;
  }
}
