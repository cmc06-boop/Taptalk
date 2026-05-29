import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../data/models/child_session_summary.dart';

class SessionUsageChart extends StatefulWidget {
  const SessionUsageChart({
    super.key,
    required this.summary,
    required this.theme,
    required this.lang,
  });

  final ChildSessionSummary summary;
  final TapTalkThemeToken theme;
  final AppLanguage lang;

  @override
  State<SessionUsageChart> createState() => _SessionUsageChartState();
}

class _SessionUsageChartState extends State<SessionUsageChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(SessionUsageChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    if (widget.summary.hasActiveSession) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final theme = widget.theme;
    final lang = widget.lang;
    final accent = theme.bgAccent;
    final textColor = theme.textMain;

    if (summary.buckets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: Text(
            AppStrings.noSessionData(lang),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: textColor.withValues(alpha: 0.65),
            ),
          ),
        ),
      );
    }

    final chartSurface = Color.alphaBlend(
      accent.withValues(alpha: 0.07),
      Color.alphaBlend(
        Colors.white.withValues(alpha: 0.14),
        Color.lerp(theme.bgLight, theme.bgMid, 0.68)!,
      ),
    );
    final glassFill = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.42),
      theme.bgLight.withValues(alpha: 0.55),
    );
    final glassBorder = Colors.white.withValues(alpha: 0.55);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary.hasActiveSession) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    return Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(
                          alpha: 0.55 + (_pulse.value * 0.45),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.sessionInProgress(lang),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                      Text(
                        AppStrings.sessionInProgressDetail(
                          summary.liveSessionMinutes,
                          lang,
                        ),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: textColor.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  AppStrings.liveUpdating(lang),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: textColor.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Container(
          height: 196,
          padding: const EdgeInsets.fromLTRB(10, 12, 8, 8),
          decoration: BoxDecoration(
            color: chartSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: textColor.withValues(alpha: 0.09),
            ),
          ),
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              return CustomPaint(
                painter: _SessionBarChartPainter(
                  buckets: summary.buckets,
                  peakMinutes: summary.chartPeakMinutes,
                  accent: accent,
                  labelColor: textColor.withValues(alpha: 0.55),
                  gridColor: textColor.withValues(alpha: 0.08),
                  livePulse: summary.hasActiveSession ? _pulse.value : 0,
                  lang: lang,
                ),
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: glassFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: glassBorder),
          ),
          child: Row(
            children: [
              _StatTile(
                label: AppStrings.totalSessionTime(lang),
                value: AppStrings.formatDurationMinutes(
                  summary.totalMinutes,
                  lang,
                ),
                accent: accent,
                textColor: textColor,
              ),
              _verticalDivider(textColor),
              _StatTile(
                label: AppStrings.sessionsCount(lang),
                value: '${summary.sessionCount}',
                accent: accent,
                textColor: textColor,
              ),
              _verticalDivider(textColor),
              _StatTile(
                label: AppStrings.avgSession(lang),
                value: AppStrings.formatDurationMinutes(
                  summary.averageSessionMinutes,
                  lang,
                ),
                accent: accent,
                textColor: textColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _verticalDivider(Color textColor) {
    return Container(
      width: 1,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      color: textColor.withValues(alpha: 0.12),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.accent,
    required this.textColor,
  });

  final String label;
  final String value;
  final Color accent;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textColor.withValues(alpha: 0.62),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionBarChartPainter extends CustomPainter {
  _SessionBarChartPainter({
    required this.buckets,
    required this.peakMinutes,
    required this.accent,
    required this.labelColor,
    required this.gridColor,
    required this.livePulse,
    required this.lang,
  });

  final List<SessionUsageBucket> buckets;
  final double peakMinutes;
  final Color accent;
  final Color labelColor;
  final Color gridColor;
  final double livePulse;
  final AppLanguage lang;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 34.0;
    const topPad = 6.0;
    const bottomPad = 24.0;
    const rightPad = 4.0;

    final chartHeight = size.height - topPad - bottomPad;
    final chartWidth = size.width - leftPad - rightPad;
    final peak = peakMinutes <= 0 ? 1.0 : peakMinutes;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var i = 0; i <= 2; i++) {
      final y = topPad + chartHeight * (i / 2);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
    }

    final yLabels = [
      AppStrings.formatDurationMinutes(peak, lang),
      AppStrings.formatDurationMinutes(peak / 2, lang),
      lang == AppLanguage.filipino ? '0m' : '0m',
    ];
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

    final count = buckets.length;
    if (count == 0) return;

    final gap = count > 20 ? 2.0 : (count > 12 ? 3.0 : 4.0);
    final barWidth = (chartWidth - gap * (count - 1)) / count;

    for (var i = 0; i < count; i++) {
      final bucket = buckets[i];
      final fraction = (bucket.minutes / peak).clamp(0.0, 1.0);
      final barHeight = math.max(
        chartHeight * fraction,
        bucket.minutes > 0 ? 3.0 : 0.0,
      );
      final left = leftPad + i * (barWidth + gap);
      final top = topPad + chartHeight - barHeight;

      final softAccent = Color.lerp(accent, Colors.white, 0.32)!;
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barWidth, barHeight),
        Radius.circular(math.min(barWidth / 2, 5)),
      );

      if (bucket.minutes <= 0) {
        canvas.drawRRect(
          barRect,
          Paint()..color = softAccent.withValues(alpha: 0.12),
        );
      } else {
        final topAlpha = bucket.isActive
            ? 0.52 + (livePulse * 0.14)
            : 0.48;
        final barPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              softAccent.withValues(alpha: 0.32),
              softAccent.withValues(alpha: topAlpha),
            ],
          ).createShader(barRect.outerRect);
        canvas.drawRRect(barRect, barPaint);
      }

      if (bucket.label.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(
            text: bucket.label,
            style: TextStyle(
              color: labelColor,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: barWidth + 16);

        tp.paint(
          canvas,
          Offset(
            left + (barWidth - tp.width) / 2,
            size.height - bottomPad + 5,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SessionBarChartPainter oldDelegate) {
    return oldDelegate.buckets != buckets ||
        oldDelegate.peakMinutes != peakMinutes ||
        oldDelegate.livePulse != livePulse ||
        oldDelegate.accent != accent;
  }
}
