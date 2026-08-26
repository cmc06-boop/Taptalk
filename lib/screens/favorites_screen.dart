import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/utils/speak_feedback.dart';
import '../data/models/favorite_model.dart';
import '../data/models/phrase_model.dart';
import '../providers/app_state.dart';
import '../widgets/category_icon.dart';
import '../widgets/learner_scaffold.dart';
import '../widgets/phrase_card.dart';
import '../widgets/view_phrase_dialog.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  static const _allCategoriesKey = '__all__';
  String _filterCategoryKey = _allCategoriesKey;
  final Set<String> _removedFavoriteKeys = {};

  Future<void> _refresh() async {
    await context.read<AppState>().refreshFavoritesFromCloud();
  }

  PhraseModel? _phraseForFavorite(AppState app, FavoriteModel favorite) {
    if (favorite.phraseId != null) {
      for (final phrase in app.phrases) {
        if (phrase.id == favorite.phraseId) return phrase;
      }
    }
    final favoriteKey =
        '${favorite.phraseText.trim().toLowerCase()}__${favorite.categoryKey}';
    for (final phrase in app.phrases) {
      final phraseKey =
          '${phrase.text.trim().toLowerCase()}__${phrase.categoryKey}';
      if (phraseKey == favoriteKey) return phrase;
    }
    return null;
  }

  bool _matchesCategoryFilter(
    AppState app,
    FavoriteModel favorite,
    String filterKey,
  ) {
    if (filterKey == _allCategoriesKey) return true;

    final favoriteKey = favorite.categoryKey.trim().toLowerCase();
    final normalizedFilter = filterKey.trim().toLowerCase();
    if (favoriteKey == normalizedFilter) return true;

    // A phrase stored under a subcategory also belongs to its top-level
    // category (for example, Fruits appears under Food and under ALL).
    for (final category in app.categories) {
      if (category.key.trim().toLowerCase() == favoriteKey) {
        final parent = category.parentKey?.trim().toLowerCase();
        return parent != null && parent == normalizedFilter;
      }
    }
    return false;
  }

  PhraseModel _displayPhrase(AppState app, FavoriteModel favorite) {
    final resolved = _phraseForFavorite(app, favorite);
    if (resolved != null) return resolved;
    return PhraseModel(
      id: favorite.phraseId ?? favorite.id,
      userId: favorite.userId,
      text: favorite.phraseText,
      categoryKey: favorite.categoryKey,
      imagePath: favorite.imagePath,
      isBuiltin: true,
    );
  }

  Future<void> _confirmDeletePhrase(
    PhraseModel phrase,
    FavoriteModel favorite,
  ) async {
    final app = context.read<AppState>();
    final lang = app.language;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: Text(AppStrings.deletePhrase(lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel(lang)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.delete(lang)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _removedFavoriteKeys.add(favorite.dedupeKey));
    await app.deletePhrase(phrase);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final snackBar = messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        content: const Text('Deleting phrase in 5 seconds'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            unawaited(app.restorePhrase(phrase, restoreFavorite: true));
            if (mounted) {
              setState(() => _removedFavoriteKeys.remove(favorite.dedupeKey));
            }
          },
        ),
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 5));
    snackBar.close();
    if (mounted) {
      setState(() => _removedFavoriteKeys.remove(favorite.dedupeKey));
    }
  }

  double _favoritesCategoryItemWidth(String label) {
    final style = GoogleFonts.poppins(
      fontSize: 9.7,
      height: 1.2,
      fontWeight: FontWeight.w700,
    );
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width.ceilToDouble().clamp(36.0, 200.0) + 2;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.language;
    final theme = app.theme;
    final denseGrid = AppSpacing.phraseGridIsDense(context);
    final filterKey = _filterCategoryKey;
    final topLevelCategories =
        app.categories.where((c) => c.isTopLevel).toList();

    final favoriteItems = app.favorites
        .where(
          (f) =>
              _matchesCategoryFilter(app, f, filterKey) &&
              !_removedFavoriteKeys.contains(f.dedupeKey),
        )
        .toList();

    return LearnerScaffold(
      title: AppStrings.favorites(lang),
      titleWidget: SizedBox(
        height: 85,
        child: Center(
          child: Text(
            AppStrings.favorites(lang),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: theme.textMain,
            ),
          ),
        ),
      ),
      currentRoute: AppRoute.favorites,
      headerContentHeight: 85,
      headerBottomSpacing: 0,
      bodyTopOffset: -4,
      onMicTap: () => app.setRoute(AppRoute.home),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: theme.bgAccent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Container(
                  width: double.infinity,
                  clipBehavior: Clip.hardEdge,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: theme.bgMid.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.categories(lang),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: theme.textMain,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      SizedBox(
                        height: 64,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.zero,
                          itemCount: topLevelCategories.length + 1,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: 15),
                          itemBuilder: (context, i) {
                            if (i == 0) {
                              final active = filterKey == _allCategoriesKey;
                              final allLabel = AppStrings.all(lang);
                              return _FavoritesCategoryItem(
                                width: _favoritesCategoryItemWidth(allLabel),
                                active: active,
                                label: allLabel,
                                accent: theme.bgAccent,
                                textColor: theme.textMain,
                                icon: Icon(
                                  Icons.grid_view_rounded,
                                  size: 18,
                                  color: active
                                      ? Colors.white
                                      : theme.bgAccent,
                                ),
                                onTap: () => setState(
                                  () => _filterCategoryKey = _allCategoriesKey,
                                ),
                              );
                            }
                            final cat = topLevelCategories[i - 1];
                            final active = cat.key == filterKey;
                            final catLabel = app.localizedCategoryName(cat);
                            return _FavoritesCategoryItem(
                              width: _favoritesCategoryItemWidth(catLabel),
                              active: active,
                              label: catLabel,
                              accent: theme.bgAccent,
                              textColor: theme.textMain,
                              icon: CategoryIcon(
                                category: cat,
                                size: 18,
                                color: active
                                    ? Colors.white
                                    : theme.bgAccent,
                              ),
                              onTap: () =>
                                  setState(() => _filterCategoryKey = cat.key),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.favoritePhrases(lang),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: theme.textMain,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (favoriteItems.isEmpty)
                      SizedBox(
                        width: double.infinity,
                        height: MediaQuery.sizeOf(context).height * 0.38,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xl,
                            ),
                            child: Text(
                              AppStrings.emptyFavoritesDesign(lang),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: theme.bgAccent.withValues(alpha: 0.85),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      GridView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: AppSpacing.phraseGridDelegate(context),
                        itemCount: favoriteItems.length,
                        itemBuilder: (context, i) {
                          final favorite = favoriteItems[i];
                          final phrase = _displayPhrase(app, favorite);
                          return PhraseCard(
                            key: ValueKey(
                              'fav_${favorite.id}_${favorite.dedupeKey}_${lang.name}_${app.languageRevision}',
                            ),
                            phrase: phrase,
                            dense: denseGrid,
                            isFavorite: true,
                            onTap: () => speakWithFeedback(
                              context,
                              app.localizedPhraseText(phrase),
                              record: true,
                              phraseId: phrase.id,
                            ),
                            onSpeak: () => speakWithFeedback(
                              context,
                              app.localizedPhraseText(phrase),
                              record: true,
                              phraseId: phrase.id,
                            ),
                            onFavorite: () => app.toggleFavorite(phrase),
                            onView: () => ViewPhraseDialog.show(
                              context,
                              phrase: phrase,
                              displayText: app.localizedPhraseText(phrase),
                            ),
                            onDelete: phrase.isBuiltin
                                ? () {}
                                : () => _confirmDeletePhrase(phrase, favorite),
                          );
                        },
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

class _FavoritesCategoryItem extends StatelessWidget {
  const _FavoritesCategoryItem({
    required this.width,
    required this.active,
    required this.label,
    required this.accent,
    required this.textColor,
    required this.icon,
    required this.onTap,
  });

  final double width;
  final bool active;
  final String label;
  final Color accent;
  final Color textColor;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? accent : accent.withValues(alpha: 0.07),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: active ? 0.38 : 0.05),
                    blurRadius: active ? 6 : 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(child: icon),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              overflow: TextOverflow.visible,
              style: GoogleFonts.poppins(
                fontSize: 9.7,
                height: 1.2,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? accent : textColor,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: active ? 12 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
