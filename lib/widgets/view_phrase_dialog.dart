import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/utils/speak_feedback.dart';
import '../data/models/phrase_model.dart';
import '../providers/app_state.dart';
import 'highlighting_text_controller.dart';
import 'phrase_image.dart';

class ViewPhraseDialog extends StatefulWidget {
  const ViewPhraseDialog({
    super.key,
    required this.phrase,
    this.displayText,
  });

  final PhraseModel phrase;
  final String? displayText;

  static Future<void> show(
    BuildContext context, {
    required PhraseModel phrase,
    String? displayText,
  }) {
    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (_) => ViewPhraseDialog(
        phrase: phrase,
        displayText: displayText,
      ),
    );
  }

  @override
  State<ViewPhraseDialog> createState() => _ViewPhraseDialogState();
}

class _ViewPhraseDialogState extends State<ViewPhraseDialog> {
  AppState? _app;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _app = context.read<AppState>();
      _app!.setPhraseVideoFromViewOnly(true);
    });
  }

  @override
  void dispose() {
    _app?.setPhraseVideoFromViewOnly(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final phrase = widget.phrase;
    final text = widget.displayText ?? app.localizedPhraseText(phrase);
    final isVideo = isPhraseVideoPath(phrase.imagePath);

    // Use Dialog + fixed width — AlertDialog + PhraseImage(fill) crashes on
    // Food pictures with: width.isFinite is not true.
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: SizedBox(
        width: 280,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        AppStrings.viewMonitoring(lang),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: theme.textMain,
                    tooltip: AppStrings.cancel(lang),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                      child: SizedBox(
                        width: 256,
                        height: 180,
                        child: Selector<AppState, bool>(
                          selector: (_, state) {
                            if (!isVideo) return false;
                            if (!state.isSpeaking) return false;
                            if (state.speakingPhraseId != null &&
                                state.speakingPhraseId == phrase.id) {
                              return true;
                            }
                            return state.speakingText.trim() == text.trim();
                          },
                          builder: (_, playing, _) {
                            return PhraseImage(
                              key: ValueKey(
                                'view_media_${phrase.id}_${phrase.imagePath}',
                              ),
                              imagePath: phrase.imagePath,
                              theme: theme,
                              fill: true,
                              playing: playing,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Selector<AppState, (bool, int, int)>(
                      selector: (_, state) {
                        final active = state.isSpeaking &&
                            state.speakingText.trim() == text.trim();
                        if (!active) return const (false, 0, 0);
                        return (
                          true,
                          state.spokenWordStart,
                          state.spokenWordEnd,
                        );
                      },
                      builder: (_, highlight, _) {
                        final (active, start, end) = highlight;
                        final style = GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: theme.textMain,
                        );
                        if (!active) {
                          return Text(
                            text,
                            textAlign: TextAlign.center,
                            style: style,
                          );
                        }
                        return RichText(
                          textAlign: TextAlign.center,
                          text: buildHighlightedTextSpan(
                            text: text,
                            start: start,
                            end: end,
                            accent: theme.bgAccent,
                            style: style,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: () => speakWithFeedback(
                        context,
                        text,
                        record: true,
                        phraseId: phrase.id,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.bgAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                      ),
                      icon: const Icon(Icons.volume_up_rounded, size: 18),
                      label: Text(
                        AppStrings.speak(lang),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
