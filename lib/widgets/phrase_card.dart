import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../data/models/phrase_model.dart';
import '../providers/app_state.dart';
import 'highlighting_text_controller.dart';
import 'phrase_image.dart';

class PhraseCard extends StatefulWidget {
  const PhraseCard({
    super.key,
    required this.phrase,
    required this.onTap,
    required this.onSpeak,
    required this.onDelete,
    required this.onFavorite,
    this.onEdit,
    this.onView,
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
  final VoidCallback? onView;
  final bool isFavorite;
  final bool showFavorite;
  final bool showDelete;
  final bool showEdit;
  final bool dense;

  @override
  State<PhraseCard> createState() => _PhraseCardState();
}

class _PhraseCardState extends State<PhraseCard>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive {
    // Home has ~58 videos — keeping every card alive starves decoders online.
    // Retention is handled by the video view after a successful load.
    if (widget.phrase.categoryKey == 'home') return false;
    return isPhraseVideoPath(widget.phrase.imagePath);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final phrase = widget.phrase;
    final displayText = widget.displayText;
    final onTap = widget.onTap;
    final onSpeak = widget.onSpeak;
    final onDelete = widget.onDelete;
    final onFavorite = widget.onFavorite;
    final onEdit = widget.onEdit;
    final onView = widget.onView;
    final isFavorite = widget.isFavorite;
    final showFavorite = widget.showFavorite;
    final showDelete = widget.showDelete;
    final showEdit = widget.showEdit;
    final dense = widget.dense;

    final theme = context.select((AppState app) => app.theme);
    final lang = context.select((AppState app) => app.language);
    final String phraseText = displayText ??
        context.select((AppState app) => app.localizedPhraseText(phrase));
    final cardRadius = dense ? AppSpacing.radiusMd : AppSpacing.radiusLg;
    final edgePad = dense ? AppSpacing.xs : AppSpacing.sm;
    final actionHeight = dense ? 28.0 : 32.0;
    final actionIcon = dense ? 14.0 : 15.0;
    final labelSize = dense ? 9.0 : 10.0;
    final titleSize = dense ? 9.5 : 11.0;
    final canEdit = showEdit && !phrase.isBuiltin && onEdit != null;
    final canDelete = showDelete && !phrase.isBuiltin;
    final canView = onView != null;
    final showMoreMenu = canView || canEdit || canDelete;
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
                          child: Selector<AppState, bool>(
                            selector: (_, app) {
                              // View dialog owns playback while open.
                              if (app.phraseVideoFromViewOnly) return false;
                              if (!app.isSpeaking) return false;
                              if (app.speakingPhraseId != null &&
                                  app.speakingPhraseId == phrase.id) {
                                return true;
                              }
                              final text = displayText ??
                                  app.localizedPhraseText(phrase);
                              return app.speakingText.trim() == text.trim();
                            },
                            builder: (_, playing, _) {
                              return PhraseImage(
                                imagePath: phrase.imagePath,
                                theme: theme,
                                fill: true,
                                playing: playing,
                              );
                            },
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
                      if (showMoreMenu)
                        Positioned(
                          top: dense ? 4 : 6,
                          right: dense ? 4 : 6,
                          child: _PhraseMoreButton(
                            size: dense ? 22 : 28,
                            iconSize: dense ? 14 : 17,
                            onView: canView ? onView : null,
                            onEdit: canEdit ? onEdit : null,
                            onDelete: canDelete ? onDelete : null,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: dense ? 3 : AppSpacing.xs),
                SizedBox(
                  height: dense ? 28 : 32,
                  child: Center(
                    child: Selector<AppState, (bool, int, int)>(
                      selector: (_, app) {
                        // View dialog owns read-along highlight while open.
                        if (app.phraseVideoFromViewOnly) {
                          return const (false, 0, 0);
                        }
                        final text =
                            displayText ?? app.localizedPhraseText(phrase);
                        final active = app.isSpeaking &&
                            app.speakingText.trim() == text.trim();
                        if (!active) return const (false, 0, 0);
                        return (
                          true,
                          app.spokenWordStart,
                          app.spokenWordEnd,
                        );
                      },
                      builder: (context, highlight, child) {
                        final (active, start, end) = highlight;
                        final text = phraseText;
                        if (!active) {
                          return Text(
                            text,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: phraseStyle,
                          );
                        }
                        return RichText(
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          text: buildHighlightedTextSpan(
                            text: text,
                            start: start,
                            end: end,
                            accent: theme.bgAccent,
                            style: phraseStyle,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(height: dense ? 3 : AppSpacing.xs),
                SizedBox(
                  height: actionHeight,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final speakWidth = constraints.maxWidth;
                      final iconOnlySpeak = dense || speakWidth < 72;
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

class _PhraseMoreButton extends StatelessWidget {
  const _PhraseMoreButton({
    required this.size,
    required this.iconSize,
    this.onView,
    this.onEdit,
    this.onDelete,
  });

  final double size;
  final double iconSize;
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

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
              if (onView != null)
                const PopupMenuItem<String>(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 18,
                        color: Color(0xFF5C3D2E),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'View',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5C3D2E),
                        ),
                      ),
                    ],
                  ),
                ),
              if (onEdit != null)
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: Color(0xFF5C3D2E),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5C3D2E),
                        ),
                      ),
                    ],
                  ),
                ),
              if (onDelete != null)
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Color(0xFFD64545),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Delete',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFD64545),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
          if (result == 'view') onView?.call();
          if (result == 'edit') onEdit?.call();
          if (result == 'delete') onDelete?.call();
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
