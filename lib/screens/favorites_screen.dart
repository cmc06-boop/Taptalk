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
import '../widgets/taptalk_logo.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  String? _filterCategoryKey;
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
    final favoriteKey = favorite.dedupeKey;
    for (final phrase in app.phrases) {
      final phraseKey =
          '${phrase.text.trim().toLowerCase()}__${phrase.categoryKey}';
      if (phraseKey == favoriteKey) return phrase;
    }
    return null;
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<AppState>().refreshFavoritesFromCloud());
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.language;
    final theme = app.theme;
    final denseGrid = AppSpacing.phraseGridIsDense(context);
    final filterKey = _filterCategoryKey ?? app.selectedCategoryKey;

    final favoriteItems = app.favorites
        .where(
          (f) =>
              f.categoryKey == filterKey &&
              !_removedFavoriteKeys.contains(f.dedupeKey),
        )
        .toList();

    return LearnerScaffold(
      title: AppStrings.appName(lang),
      titleWidget: const TapTalkHeaderWordmark(),
      currentRoute: AppRoute.favorites,
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
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.bgMid.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.favorites(lang),
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: theme.textMain,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      AppStrings.favoritesHint(lang),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: theme.textMain.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                AppStrings.categories(lang),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: theme.textMain,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: app.categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final cat = app.categories[i];
                  final active = cat.key == filterKey;
                  return FilterChip(
                    selected: active,
                    showCheckmark: false,
                    avatar: CategoryIcon(
                      category: cat,
                      size: 16,
                      color: active ? Colors.white : cat.accentColor,
                    ),
                    label: Text(app.localizedCategoryName(cat)),
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      color: active ? Colors.white : theme.textMain,
                    ),
                    selectedColor: theme.bgAccent,
                    backgroundColor: Colors.white.withValues(alpha: 0.65),
                    side: BorderSide(color: theme.bgMid, width: 1.5),
                    onSelected: (_) => setState(() => _filterCategoryKey = cat.key),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                AppStrings.favoritePhrases(lang),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: theme.textMain,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (favoriteItems.isEmpty)
              SizedBox(
                width: double.infinity,
                height: MediaQuery.sizeOf(context).height * 0.38,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 72,
                          color: Color(0xFFFFC107),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          AppStrings.emptyFavoritesDesign(lang),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: theme.bgAccent.withValues(alpha: 0.85),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: GridView.builder(
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
                            ),
                        onSpeak: () => speakWithFeedback(
                              context,
                              app.localizedPhraseText(phrase),
                              record: true,
                            ),
                        onFavorite: () => app.toggleFavorite(phrase),
                        onDelete: phrase.isBuiltin
                            ? () {}
                            : () => _confirmDeletePhrase(phrase, favorite),
                    );
                  },
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }
}
