import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
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
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: SizedBox(
        width: 292,
        child: _ViewGlassPanel(
          theme: theme,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: _ViewGlassPanel(
            theme: theme,
            nested: true,
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 16),
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                      child: SizedBox(
                        width: 252,
                        height: 180,
                        child: Selector<AppState, bool>(
                          selector: (_, state) =>
                              isVideo && state.isSpeaking,
                          builder: (_, playing, _) {
                            return PhraseImage(
                              key: ValueKey(
                                'view_media_${phrase.id}_${phrase.imagePath}',
                              ),
                              imagePath: phrase.imagePath,
                              theme: theme,
                              fill: true,
                              playing: playing,
                              keepReady: isVideo,
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
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 1,
                    shadowColor: theme.textMain.withValues(alpha: 0.18),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.pop(context),
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: theme.textMain,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewGlassPanel extends StatelessWidget {
  const _ViewGlassPanel({
    required this.theme,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.nested = false,
  });

  final TapTalkThemeToken theme;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool nested;

  @override
  Widget build(BuildContext context) {
    final radius = nested ? 18.0 : 24.0;
    final fill = nested
        ? Color.alphaBlend(
            Colors.white.withValues(alpha: 0.52),
            theme.bgLight.withValues(alpha: 0.46),
          )
        : Color.alphaBlend(
            Colors.white.withValues(alpha: 0.22),
            theme.bgLight.withValues(alpha: 0.28),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: nested ? 22 : 28,
                sigmaY: nested ? 22 : 28,
              ),
              child: ColoredBox(color: fill),
            ),
          ),
          if (nested)
            Positioned.fill(
              child: IgnorePointer(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: -22,
                      left: -20,
                      child: _ThemeBlob(
                        size: 86,
                        color: theme.bgAccent.withValues(alpha: 0.34),
                      ),
                    ),
                    Positioned(
                      top: -14,
                      right: 42,
                      child: _ThemeBlob(
                        size: 62,
                        color: theme.bgMid.withValues(alpha: 0.42),
                      ),
                    ),
                    Positioned(
                      bottom: -20,
                      right: -18,
                      child: _ThemeBlob(
                        size: 82,
                        color: theme.bgAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    Positioned(
                      bottom: 58,
                      left: -26,
                      child: _ThemeBlob(
                        size: 68,
                        color: theme.bgMid.withValues(alpha: 0.38),
                      ),
                    ),
                    Positioned(
                      bottom: -12,
                      left: 74,
                      child: _ThemeBlob(
                        size: 54,
                        color: Color.lerp(theme.bgAccent, Colors.white, 0.3)!
                            .withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Diagonal sheen + softly blurred rim so the edge reads as curved
          // glass instead of a hard outline.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: nested ? 0.34 : 0.22),
                      Colors.white.withValues(alpha: 0.05),
                      Colors.transparent,
                      Colors.white.withValues(alpha: nested ? 0.18 : 0.12),
                    ],
                    stops: const [0, 0.3, 0.66, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 1.6, sigmaY: 1.6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: nested ? 0.9 : 0.6),
                      width: nested ? 2.2 : 1.6,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class _ThemeBlob extends StatelessWidget {
  const _ThemeBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}
