import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../data/models/phrase_model.dart';
import '../providers/app_state.dart';
import 'compact_popup_menu.dart';
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
  bool get wantKeepAlive => false;

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

    final mediaRadius = dense ? 8.0 : 10.0;

    return Container(
      decoration: BoxDecoration(
        color: theme.bgMid,
        borderRadius: BorderRadius.circular(cardRadius),
        boxShadow: [
          BoxShadow(
            color: Color.lerp(theme.bgAccent, theme.textMain, 0.35)!
                .withValues(alpha: 0.42),
            blurRadius: 5,
            spreadRadius: 0,
            offset: Offset.zero,
          ),
        ],
      ),
      child: Material(
        color: theme.bgMid,
        elevation: 0,
        shadowColor: Colors.transparent,
        borderRadius: BorderRadius.circular(cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(cardRadius),
          child: Ink(
            decoration: BoxDecoration(
              color: theme.bgMid,
              borderRadius: BorderRadius.circular(cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: dense ? 4 : 5),
                    child: Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(cardRadius),
                              topRight: Radius.circular(cardRadius),
                              bottomLeft: Radius.circular(mediaRadius),
                              bottomRight: Radius.circular(mediaRadius),
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
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  edgePad,
                  dense ? 4 : 6,
                  edgePad,
                  edgePad,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: dense ? 6 : 10,
                  ),
                  child: SizedBox(
                    height: actionHeight,
                    width: double.infinity,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final iconOnlySpeak =
                            dense || constraints.maxWidth < 72;
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
                        return iconOnlySpeak
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
                              );
                      },
                    ),
                  ),
                ),
                  ],
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
    final lang = context.watch<AppState>().language;
    return CompactPopupMenu(
      vertical: true,
      buttonWidth: size,
      buttonHeight: size,
      dotsSize: iconSize,
      buttonBackground: Colors.white.withValues(alpha: 0.92),
      iconColor: const Color(0xFF5C3D2E),
      onSelected: (value) {
        if (value == 'view') onView?.call();
        if (value == 'edit') onEdit?.call();
        if (value == 'delete') onDelete?.call();
      },
      actions: [
        if (onView != null)
          CompactMenuAction(
            value: 'view',
            label: AppStrings.view(lang),
            icon: Icons.visibility_outlined,
            color: const Color(0xFF5C3D2E),
          ),
        if (onEdit != null)
          CompactMenuAction(
            value: 'edit',
            label: AppStrings.edit(lang),
            icon: Icons.edit_outlined,
            color: const Color(0xFF5C3D2E),
          ),
        if (onDelete != null)
          CompactMenuAction(
            value: 'delete',
            label: AppStrings.delete(lang),
            icon: Icons.delete_outline_rounded,
            color: const Color(0xFFD64545),
          ),
      ],
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
