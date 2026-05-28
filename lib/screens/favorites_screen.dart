import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/utils/speak_feedback.dart';
import '../data/models/phrase_model.dart';
import '../providers/app_state.dart';
import '../widgets/learner_scaffold.dart';
import '../widgets/phrase_card.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  String? _filterCategoryKey;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.language;
    final theme = app.theme;
    final columns = AppSpacing.phraseGridColumns(context);
    final filterKey = _filterCategoryKey ?? app.selectedCategoryKey;

    final phrases = app.favorites
        .where((f) => f.categoryKey == filterKey)
        .map((f) {
      return PhraseModel(
        id: f.phraseId ?? f.id,
        userId: f.userId,
        text: f.phraseText,
        categoryKey: f.categoryKey,
        imagePath: f.imagePath,
      );
    }).toList();

    return LearnerScaffold(
      title: AppStrings.appName(lang),
      currentRoute: AppRoute.favorites,
      onMicTap: () => app.setRoute(AppRoute.home),
      body: SingleChildScrollView(
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
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: theme.textMain,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      AppStrings.favoritesHint(lang),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.bgAccent,
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
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: theme.textMain,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 44,
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
                    label: Text(app.localizedCategoryName(cat)),
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      color: active ? Colors.white : theme.textMain,
                    ),
                    selectedColor: theme.bgAccent,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: theme.bgAccent, width: 1.5),
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
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: theme.textMain,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (phrases.isEmpty)
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
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 0.86,
                  ),
                  itemCount: phrases.length,
                  itemBuilder: (context, i) {
                    final phrase = phrases[i];
                    return Align(
                      alignment: Alignment.topCenter,
                      child: PhraseCard(
                        phrase: phrase,
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
                        onDelete: () {},
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
