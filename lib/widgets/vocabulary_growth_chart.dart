import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../data/models/vocabulary_growth_summary.dart';

const _chartLeftPad = 28.0;
const _chartTopPad = 8.0;
const _chartBottomPad = 26.0;
const _chartRightPad = 8.0;
const _chartHeight = 168.0;

class VocabularyGrowthChart extends StatefulWidget {
  const VocabularyGrowthChart({
    super.key,
    required this.points,
    required this.theme,
    required this.lang,
    this.showCumulative = false,
    this.emptyMessage,
  });

  final List<VocabularyGrowthPoint> points;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final bool showCumulative;
  final String? emptyMessage;

  @override
  State<VocabularyGrowthChart> createState() => _VocabularyGrowthChartState();
}

class _VocabularyGrowthChartState extends State<VocabularyGrowthChart> {
  static const _tooltipVisibleFor = Duration(milliseconds: 2500);
  static const _tooltipEstimatedHeight = 48.0;

  int? _selectedIndex;
  Timer? _dismissTimer;

  @override
  void didUpdateWidget(VocabularyGrowthChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points.length != widget.points.length ||
        oldWidget.showCumulative != widget.showCumulative) {
      _dismissTimer?.cancel();
      _selectedIndex = null;
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  List<double> get _values => widget.points
      .map(
        (p) => widget.showCumulative
            ? p.cumulativeWords.toDouble()
            : p.newWords.toDouble(),
      )
      .toList();

  double _peakOf(List<double> values) {
    final peak = values.fold<double>(0, math.max);
    return peak <= 0 ? 1.0 : peak;
  }

  void _selectNearest(Offset position, double width) {
    final count = widget.points.length;
    if (count < 2) return;
    final chartWidth = width - _chartLeftPad - _chartRightPad;
    if (chartWidth <= 0) return;
    final stepX = chartWidth / (count - 1);
    final index = ((position.dx - _chartLeftPad) / stepX).round().clamp(
          0,
          count - 1,
        );

    _dismissTimer?.cancel();
    setState(() => _selectedIndex = index);
    _dismissTimer = Timer(_tooltipVisibleFor, () {
      if (!mounted) return;
      setState(() => _selectedIndex = null);
    });
  }

  Offset _offsetForIndex(int index, double width, List<double> values) {
    final chartWidth = width - _chartLeftPad - _chartRightPad;
    final chartArea = _chartHeight - _chartTopPad - _chartBottomPad;
    final stepX = chartWidth / (widget.points.length - 1);
    final fraction = (values[index] / _peakOf(values)).clamp(0.0, 1.0);
    return Offset(
      _chartLeftPad + stepX * index,
      _chartTopPad + chartArea * (1 - fraction),
    );
  }

  String _tooltipValue(int count, bool cumulative, AppLanguage lang) {
    if (lang == AppLanguage.filipino) {
      return cumulative ? '$count sa kabuuan' : '$count bagong parirala';
    }
    if (cumulative) return '$count in total';
    return count == 1 ? '1 new phrase' : '$count new phrases';
  }

  Widget _buildTooltip({
    required int index,
    required double width,
    required List<double> values,
    required Color accent,
    required TapTalkThemeToken theme,
    required AppLanguage lang,
    required bool showCumulative,
  }) {
    final point = widget.points[index];
    final anchor = _offsetForIndex(index, width, values);

    final maxTop = math.max(
      0.0,
      _chartHeight - _chartBottomPad - _tooltipEstimatedHeight,
    );
    var top = anchor.dy - _tooltipEstimatedHeight - 10;
    if (top < 0) top = anchor.dy + 12;
    top = top.clamp(0.0, maxTop);

    final alignX = width <= 0
        ? 0.0
        : ((anchor.dx / width) * 2 - 1).clamp(-1.0, 1.0);
    final count = showCumulative
        ? point.cumulativeWords
        : point.newWords;

    return Positioned(
      left: 0,
      right: 0,
      top: top,
      child: IgnorePointer(
        child: Align(
          alignment: Alignment(alignX, 0),
          heightFactor: 1,
          child: _TrendTooltip(
            detail: point.detail.isEmpty ? point.label : point.detail,
            value: _tooltipValue(count, showCumulative, lang),
            accent: accent,
            textColor: theme.textMain,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final theme = widget.theme;
    final lang = widget.lang;
    final showCumulative = widget.showCumulative;

    if (points.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: Text(
            widget.emptyMessage ?? AppStrings.noVocabularyData(lang),
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

    final values = _values;
    final displayPeak = _peakOf(values);
    final selected = _selectedIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _chartHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) =>
                    _selectNearest(details.localPosition, width),
                child: Stack(
                  children: [
                    Positioned.fill(
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
                          selectedIndex: selected,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    if (selected != null)
                      _buildTooltip(
                        index: selected,
                        width: width,
                        values: values,
                        accent: accent,
                        theme: theme,
                        lang: lang,
                        showCumulative: showCumulative,
                      ),
                  ],
                ),
              );
            },
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

class _TrendTooltip extends StatelessWidget {
  const _TrendTooltip({
    required this.detail,
    required this.value,
    required this.accent,
    required this.textColor,
  });

  final String detail;
  final String value;
  final Color accent;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            detail,
            style: GoogleFonts.poppins(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: textColor.withValues(alpha: 0.58),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
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
    required this.selectedIndex,
  });

  final List<VocabularyGrowthPoint> points;
  final List<double> values;
  final double peak;
  final Color accent;
  final Color labelColor;
  final Color gridColor;
  final Color fillColor;
  final Color lineColor;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = _chartLeftPad;
    const topPad = _chartTopPad;
    const bottomPad = _chartBottomPad;
    const rightPad = _chartRightPad;

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

    final selected = selectedIndex;
    if (selected != null && selected >= 0 && selected < coords.length) {
      final x = coords[selected].dx;
      canvas.drawLine(
        Offset(x, topPad),
        Offset(x, topPad + chartHeight),
        Paint()
          ..color = accent.withValues(alpha: 0.30)
          ..strokeWidth = 1.2,
      );
    }

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

    if (selected != null && selected >= 0 && selected < coords.length) {
      final point = coords[selected];
      canvas.drawCircle(
        point,
        9,
        Paint()..color = accent.withValues(alpha: 0.20),
      );
      canvas.drawCircle(point, 5.4, Paint()..color = Colors.white);
      canvas.drawCircle(point, 3.8, Paint()..color = lineColor);
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
        oldDelegate.peak != peak ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}
