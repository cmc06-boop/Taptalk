import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../data/models/phrase_model.dart';
import '../providers/app_state.dart';
import 'phrase_image.dart';

class PhraseCard extends StatelessWidget {
  const PhraseCard({
    super.key,
    required this.phrase,
    required this.onTap,
    required this.onSpeak,
    required this.onDelete,
    required this.onFavorite,
    required this.isFavorite,
    this.showFavorite = true,
    this.showDelete = true,
    this.dense = false,
  });

  final PhraseModel phrase;
  final VoidCallback onTap;
  final VoidCallback onSpeak;
  final VoidCallback onDelete;
  final VoidCallback onFavorite;
  final bool isFavorite;
  final bool showFavorite;
  final bool showDelete;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final cardRadius = dense ? AppSpacing.radiusMd : AppSpacing.radiusLg;
    final edgePad = dense ? AppSpacing.xs : AppSpacing.sm;
    final imageAspect = dense ? 1.15 : 1.45;
    final actionHeight = dense ? 28.0 : 34.0;
    final actionIcon = dense ? 14.0 : 16.0;
    final labelSize = dense ? 9.0 : 11.0;
    final titleSize = dense ? 10.0 : 12.0;

    return Material(
      color: theme.bgMid,
      elevation: 0,
      shadowColor: theme.textMain.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(cardRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: theme.bgMid,
            borderRadius: BorderRadius.circular(cardRadius),
            boxShadow: [
              BoxShadow(
                color: theme.textMain.withValues(alpha: dense ? 0.08 : 0.1),
                blurRadius: dense ? 8 : 14,
                offset: Offset(0, dense ? 3 : 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(edgePad, edgePad, edgePad, 0),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        dense ? AppSpacing.radiusSm : AppSpacing.radiusMd,
                      ),
                      child: PhraseImage(
                        imagePath: phrase.imagePath,
                        theme: theme,
                        aspectRatio: imageAspect,
                      ),
                    ),
                    if (showFavorite)
                      Positioned(
                        top: dense ? 4 : 6,
                        right: dense ? 4 : 6,
                        child: _StarButton(
                          active: isFavorite,
                          onTap: onFavorite,
                          size: dense ? 22 : 28,
                          iconSize: dense ? 14 : 17,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(edgePad, AppSpacing.xs, edgePad, 0),
                child: Text(
                  app.localizedPhraseText(phrase),
                  textAlign: TextAlign.center,
                  maxLines: dense ? 2 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w800,
                    color: theme.textMain,
                    height: 1.05,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  edgePad,
                  AppSpacing.xs,
                  edgePad,
                  edgePad,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onSpeak,
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.bgAccent,
                          foregroundColor: Colors.white,
                          minimumSize: Size(0, actionHeight),
                          padding: EdgeInsets.symmetric(
                            horizontal: dense ? 2 : AppSpacing.xs,
                            vertical: dense ? 2 : AppSpacing.xs,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              dense ? 8 : AppSpacing.radiusSm,
                            ),
                          ),
                          elevation: 0,
                        ),
                        icon: Icon(Icons.volume_up_rounded, size: actionIcon),
                        label: dense
                            ? const SizedBox.shrink()
                            : Text(
                                AppStrings.speak(lang),
                                style: GoogleFonts.poppins(
                                  fontSize: labelSize,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    if (showDelete) ...[
                      SizedBox(width: dense ? AppSpacing.xs : AppSpacing.sm),
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          dense ? 8 : AppSpacing.radiusSm,
                        ),
                        elevation: 0,
                        child: InkWell(
                          onTap: onDelete,
                          borderRadius: BorderRadius.circular(
                            dense ? 8 : AppSpacing.radiusSm,
                          ),
                          child: SizedBox(
                            width: actionHeight,
                            height: actionHeight,
                            child: Icon(
                              Icons.delete_outline_rounded,
                              size: dense ? 15 : 18,
                              color: const Color(0xFF5C3D2E),
                            ),
                          ),
                        ),
                      ),
                    ],
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

class _StarButton extends StatelessWidget {
  const _StarButton({
    required this.active,
    required this.onTap,
    this.size = 28,
    this.iconSize = 17,
  });

  final bool active;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            active ? Icons.star_rounded : Icons.star_border_rounded,
            size: iconSize,
            color: active ? const Color(0xFFF9B509) : const Color(0xFF9E9E9E),
          ),
        ),
      ),
    );
  }
}
