import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../data/models/phrase_model.dart';
import '../providers/app_state.dart';
import 'highlighting_text_controller.dart';
import 'phrase_image.dart';

class PhraseCard extends StatelessWidget {
  const PhraseCard({
    super.key,
    required this.phrase,
    required this.onTap,
    required this.onSpeak,
    required this.onDelete,
    required this.onFavorite,
    this.onEdit,
    required this.isFavorite,
    this.displayText,
    this.showFavorite = true,
    this.showDelete = true,
    this.showEdit = true,
    this.dense = false,
  });

  final PhraseModel phrase;
  final String? displayText;
  final VoidCallback onTap;
  final VoidCallback onSpeak;
  final VoidCallback onDelete;
  final VoidCallback onFavorite;
  final VoidCallback? onEdit;
  final bool isFavorite;
  final bool showFavorite;
  final bool showDelete;
  final bool showEdit;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final cardRadius = dense ? AppSpacing.radiusMd : AppSpacing.radiusLg;
    final edgePad = dense ? AppSpacing.xs : AppSpacing.sm;
    final actionHeight = dense ? 28.0 : 32.0;
    final actionIcon = dense ? 14.0 : 15.0;
    final labelSize = dense ? 9.0 : 10.0;
    final titleSize = dense ? 9.5 : 11.0;
    final phraseText = displayText ??
        app.localizedPhraseText(phrase);
    final canEdit = showEdit && !phrase.isBuiltin && onEdit != null;
    final canDelete = showDelete && !phrase.isBuiltin;
    final isSpeakingThisPhrase = app.isSpeaking &&
        app.speakingText.trim() == phraseText.trim();
    final phraseStyle = GoogleFonts.poppins(
      fontSize: titleSize,
      fontWeight: FontWeight.w800,
      color: theme.textMain,
      height: 1.12,
    );

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
          child: Padding(
            padding: EdgeInsets.all(edgePad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            dense ? AppSpacing.radiusSm : AppSpacing.radiusMd,
                          ),
                          child: PhraseImage(
                            imagePath: phrase.imagePath,
                            theme: theme,
                            fill: true,
                          ),
                        ),
                      ),
                      if (showFavorite)
                        Positioned(
                          top: dense ? 4 : 6,
                          left: dense ? 4 : 6,
                          child: _StarButton(
                            active: isFavorite,
                            onTap: onFavorite,
                            size: dense ? 22 : 28,
                            iconSize: dense ? 14 : 17,
                          ),
                        ),
                      if (canEdit)
                        Positioned(
                          top: dense ? 4 : 6,
                          right: dense ? 4 : 6,
                          child: _PhraseMoreButton(
                            size: dense ? 22 : 28,
                            iconSize: dense ? 14 : 17,
                            onEdit: onEdit!,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: dense ? 3 : AppSpacing.xs),
                SizedBox(
                  height: dense ? 28 : 32,
                  child: Center(
                    child: isSpeakingThisPhrase
                        ? RichText(
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            text: buildHighlightedTextSpan(
                              text: phraseText,
                              start: app.spokenWordStart,
                              end: app.spokenWordEnd,
                              accent: theme.bgAccent,
                              style: phraseStyle,
                            ),
                          )
                        : Text(
                            phraseText,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: phraseStyle,
                          ),
                  ),
                ),
                SizedBox(height: dense ? 3 : AppSpacing.xs),
                SizedBox(
                  height: actionHeight,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final sideCount = (showDelete ? 1 : 0);
                      final gap = AppSpacing.xs;
                      final sideWidth =
                          sideCount * actionHeight + (sideCount > 0 ? sideCount * gap : 0);
                      final speakWidth = constraints.maxWidth - sideWidth;
                      final iconOnlySpeak = dense || sideCount > 0 || speakWidth < 72;
                      final speakStyle = FilledButton.styleFrom(
                        backgroundColor: theme.bgAccent,
                        foregroundColor: Colors.white,
                        minimumSize: Size(0, actionHeight),
                        padding: EdgeInsets.symmetric(
                          horizontal: iconOnlySpeak ? 0 : AppSpacing.xs,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            dense ? 8 : AppSpacing.radiusSm,
                          ),
                        ),
                        elevation: 0,
                      );

                      return Row(
                        children: [
                          Expanded(
                            child: iconOnlySpeak
                                ? FilledButton(
                                    onPressed: onSpeak,
                                    style: speakStyle,
                                    child: Icon(
                                      Icons.volume_up_rounded,
                                      size: actionIcon,
                                    ),
                                  )
                                : FilledButton.icon(
                                    onPressed: onSpeak,
                                    style: speakStyle,
                                    icon: Icon(
                                      Icons.volume_up_rounded,
                                      size: actionIcon,
                                    ),
                                    label: Text(
                                      AppStrings.speak(lang),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontSize: labelSize,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                          ),
                          if (canDelete) ...[
                            SizedBox(width: gap),
                            _PhraseActionButton(
                              icon: Icons.delete_outline_rounded,
                              size: actionHeight,
                              iconSize: dense ? 15 : 18,
                              radius: dense ? 8 : AppSpacing.radiusSm,
                              onTap: onDelete,
                            ),
                          ],
                        ],
                      );
                    },
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

class _PhraseActionButton extends StatelessWidget {
  const _PhraseActionButton({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.radius,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final double radius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: iconSize,
            color: const Color(0xFF5C3D2E),
          ),
        ),
      ),
    );
  }
}

class _PhraseMoreButton extends StatelessWidget {
  const _PhraseMoreButton({
    required this.size,
    required this.iconSize,
    required this.onEdit,
  });

  final double size;
  final double iconSize;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () async {
          final RenderBox button = context.findRenderObject() as RenderBox;
          final RenderBox overlay =
              Overlay.of(context).context.findRenderObject() as RenderBox;
          final RelativeRect position = RelativeRect.fromRect(
            Rect.fromPoints(
              button.localToGlobal(Offset.zero, ancestor: overlay),
              button.localToGlobal(
                button.size.bottomRight(Offset.zero),
                ancestor: overlay,
              ),
            ),
            Offset.zero & overlay.size,
          );
          final result = await showMenu<String>(
            context: context,
            position: position,
            items: [
              PopupMenuItem<String>(
                value: 'edit',
                child: Row(
                  children: [
                    const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF5C3D2E)),
                    const SizedBox(width: 8),
                    Text(
                      'Edit',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5C3D2E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          if (result == 'edit') onEdit();
        },
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            Icons.more_vert_rounded,
            size: iconSize,
            color: const Color(0xFF5C3D2E),
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
