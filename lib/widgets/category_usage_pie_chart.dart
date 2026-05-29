import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../data/models/vocabulary_growth_summary.dart';

class CategoryUsagePieChart extends StatelessWidget {
  const CategoryUsagePieChart({
    super.key,
    required this.slices,
    required this.theme,
    required this.lang,
    required this.labelForCategory,
  });

  final List<CategoryVocabularySlice> slices;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final String Function(String categoryKey) labelForCategory;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: Text(
            AppStrings.noVocabularyData(lang),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: theme.textMain.withValues(alpha: 0.65),
            ),
          ),
        ),
      );
    }

    final total = slices.fold<int>(0, (sum, s) => sum + s.usageCount);
    final colors = _sliceColors(theme, slices.length);
    final topSlices = slices.take(6).toList();
    final otherCount = slices.skip(6).fold<int>(0, (sum, s) => sum + s.usageCount);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 132,
          height: 132,
          child: CustomPaint(
            painter: _DonutPainter(
              values: [
                ...topSlices.map((s) => s.usageCount.toDouble()),
                if (otherCount > 0) otherCount.toDouble(),
              ],
              colors: [
                ...colors.take(topSlices.length),
                theme.textMain.withValues(alpha: 0.22),
              ],
              strokeWidth: 22,
              centerLabel: total > 0 ? '$total' : '0',
              centerSubLabel: lang == AppLanguage.filipino ? 'gamit' : 'uses',
              labelColor: theme.textMain,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < topSlices.length; i++)
                _LegendRow(
                  color: colors[i],
                  label: labelForCategory(topSlices[i].categoryKey),
                  detail: AppStrings.vocabularyWords(
                    topSlices[i].wordCount,
                    lang,
                  ),
                  percent: total > 0
                      ? (topSlices[i].usageCount / total * 100).round()
                      : 0,
                  textColor: theme.textMain,
                ),
              if (otherCount > 0)
                _LegendRow(
                  color: theme.textMain.withValues(alpha: 0.22),
                  label: lang == AppLanguage.filipino ? 'Iba pa' : 'Other',
                  detail: AppStrings.vocabularyWords(
                    slices.skip(6).fold<int>(0, (s, e) => s + e.wordCount),
                    lang,
                  ),
                  percent: total > 0 ? (otherCount / total * 100).round() : 0,
                  textColor: theme.textMain,
                ),
            ],
          ),
        ),
      ],
    );
  }

  static List<Color> _sliceColors(TapTalkThemeToken theme, int count) {
    final base = theme.bgAccent;
    return List.generate(math.max(count, 1), (i) {
      final t = i / math.max(count - 1, 1);
      return Color.lerp(
        base.withValues(alpha: 0.95),
        base.withValues(alpha: 0.35),
        t * 0.75,
      )!;
    });
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.detail,
    required this.percent,
    required this.textColor,
  });

  final Color color;
  final String label;
  final String detail;
  final int percent;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                Text(
                  '$detail · $percent%',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: textColor.withValues(alpha: 0.58),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.values,
    required this.colors,
    required this.strokeWidth,
    required this.centerLabel,
    required this.centerSubLabel,
    required this.labelColor,
  });

  final List<double> values;
  final List<Color> colors;
  final double strokeWidth;
  final String centerLabel;
  final String centerSubLabel;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;

    if (total <= 0) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = labelColor.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
    } else {
      var start = -math.pi / 2;
      for (var i = 0; i < values.length; i++) {
        final sweep = (values[i] / total) * 2 * math.pi;
        final paint = Paint()
          ..color = colors[i % colors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          start,
          sweep,
          false,
          paint,
        );
        start += sweep;
      }
    }

    final titleTp = TextPainter(
      text: TextSpan(
        text: centerLabel,
        style: TextStyle(
          color: labelColor,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    titleTp.paint(
      canvas,
      Offset(center.dx - titleTp.width / 2, center.dy - titleTp.height / 2 - 4),
    );

    final subTp = TextPainter(
      text: TextSpan(
        text: centerSubLabel,
        style: TextStyle(
          color: labelColor.withValues(alpha: 0.55),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    subTp.paint(
      canvas,
      Offset(center.dx - subTp.width / 2, center.dy + 6),
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.colors != colors;
  }
}
