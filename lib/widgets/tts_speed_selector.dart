import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/constants/tts_speed_options.dart';
import '../providers/app_state.dart';

class TtsSpeedSelector extends StatefulWidget {
  const TtsSpeedSelector({
    super.key,
    this.showScaleLabels = false,
    this.sectionLabel,
  });

  final bool showScaleLabels;
  final String? sectionLabel;

  @override
  State<TtsSpeedSelector> createState() => _TtsSpeedSelectorState();
}

class _TtsSpeedSelectorState extends State<TtsSpeedSelector> {
  double? _liveSliderIndex;

  void _applySpeed(AppState app, double index) {
    final snapped = TtsSpeedOptions.valueAtIndex(index.round());
    app.setTtsSpeed(snapped);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final committedSpeed = TtsSpeedOptions.snap(app.ttsSpeed);
    final committedIndex = TtsSpeedOptions.indexOf(committedSpeed).toDouble();
    final sliderIndex = _liveSliderIndex ?? committedIndex;
    final displaySpeed = TtsSpeedOptions.valueAtIndex(sliderIndex.round());
    final displayLabel = TtsSpeedOptions.shortLabel(displaySpeed);

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
        onChanged: (index) => setState(() => _liveSliderIndex = index),
        onChangeEnd: (index) {
          setState(() => _liveSliderIndex = null);
          _applySpeed(app, index);
        },
      ),
    );

    if (!widget.showScaleLabels) {
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
            if (widget.sectionLabel != null)
              Expanded(
                child: Text(
                  widget.sectionLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.textMain.withValues(alpha: 0.85),
                  ),
                ),
              ),
            if (widget.sectionLabel != null)
              const SizedBox(width: AppSpacing.sm),
            Text(
              displayLabel,
              maxLines: 1,
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
                  onTap: () => _applySpeed(app, i.toDouble()),
                  child: Align(
                    alignment: i == 0
                        ? Alignment.centerLeft
                        : i == TtsSpeedOptions.scaleMarks.length - 1
                            ? Alignment.centerRight
                            : Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        TtsSpeedOptions.shortLabel(TtsSpeedOptions.scaleMarks[i]),
                        maxLines: 1,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: displaySpeed == TtsSpeedOptions.scaleMarks[i]
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: displaySpeed == TtsSpeedOptions.scaleMarks[i]
                              ? theme.textMain
                              : theme.textMain.withValues(alpha: 0.5),
                        ),
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
