import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/constants/tts_speed_options.dart';
import '../providers/app_state.dart';

class TtsSpeedSelector extends StatelessWidget {
  const TtsSpeedSelector({
    super.key,
    this.showScaleLabels = false,
    this.sectionLabel,
  });

  final bool showScaleLabels;
  final String? sectionLabel;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final speed = TtsSpeedOptions.snap(app.ttsSpeed);
    final displayLabel = TtsSpeedOptions.shortLabel(speed);
    final sliderIndex = TtsSpeedOptions.indexOf(speed).toDouble();

    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: theme.bgAccent,
        inactiveTrackColor: theme.textMain.withValues(alpha: 0.85),
        thumbColor: theme.bgAccent,
        overlayColor: theme.bgAccent.withValues(alpha: 0.2),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      child: Slider(
        value: sliderIndex,
        min: 0,
        max: TtsSpeedOptions.sliderDivisions.toDouble(),
        divisions: TtsSpeedOptions.sliderDivisions,
        onChanged: (index) =>
            app.setTtsSpeed(TtsSpeedOptions.valueAtIndex(index.round())),
      ),
    );

    if (!showScaleLabels) {
      return Row(
        children: [
          Expanded(child: slider),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 52,
            child: Text(
              displayLabel,
              textAlign: TextAlign.end,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.textMain,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (sectionLabel != null)
              Text(
                sectionLabel!,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.textMain.withValues(alpha: 0.85),
                ),
              ),
            const Spacer(),
            Text(
              displayLabel,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: theme.textMain,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        slider,
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            for (var i = 0; i < TtsSpeedOptions.scaleMarks.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => app.setTtsSpeed(TtsSpeedOptions.scaleMarks[i]),
                  child: Align(
                    alignment: i == 0
                        ? Alignment.centerLeft
                        : i == TtsSpeedOptions.scaleMarks.length - 1
                            ? Alignment.centerRight
                            : Alignment.center,
                    child: Text(
                      TtsSpeedOptions.shortLabel(TtsSpeedOptions.scaleMarks[i]),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: speed == TtsSpeedOptions.scaleMarks[i]
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: speed == TtsSpeedOptions.scaleMarks[i]
                            ? theme.textMain
                            : theme.textMain.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
