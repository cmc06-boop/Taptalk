import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';
import '../widgets/add_category_dialog.dart';
import '../widgets/category_grid_card.dart';
import '../widgets/learner_scaffold.dart';
import '../widgets/panel_card.dart';
import '../widgets/taptalk_logo.dart';

class ChooseCategoryScreen extends StatelessWidget {
  const ChooseCategoryScreen({super.key});

  Future<void> _showAddCategoryDialog(BuildContext context) async {
    await AddCategoryDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.language;
    final theme = app.theme;
    final name = app.welcomeFirstName(lang);

    return LearnerScaffold(
      title: AppStrings.appName(lang),
      titleWidget: const TapTalkHeaderWordmark(),
      currentRoute: AppRoute.chooseCategory,
      headerBottomSpacing: 0,
      bodyTopOffset: -4,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => app.refreshLearnerCollections(),
            color: theme.bgAccent,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                PanelCard(
                  borderRadius: 14,
                  margin: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.welcomeUser(name, lang),
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: theme.textMain,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        AppStrings.chooseCategorySub(lang),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: theme.textMain.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xs,
                    AppSpacing.lg,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.chooseCategoryTitle(lang),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: theme.textMain,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      GridView.builder(
                        key: ValueKey(
                          'cats_${lang.name}_${app.languageRevision}_${app.topLevelCategories.length}',
                        ),
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: AppSpacing.phraseGridDelegate(context),
                        itemCount: app.topLevelCategories.length,
                        itemBuilder: (context, i) {
                          final cat = app.topLevelCategories[i];
                          return CategoryGridCard(
                            category: cat,
                            label: app.localizedCategoryName(cat),
                            selected: cat.key == app.selectedCategoryKey,
                            onTap: () => app.completeCategorySelection(cat.key),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: AppSpacing.lg,
            bottom: AppSpacing.md,
            child: FloatingActionButton(
              onPressed: () => _showAddCategoryDialog(context),
              backgroundColor: theme.bgAccent,
              foregroundColor: Colors.white,
              tooltip: AppStrings.addCategoryShort(lang),
              child: const Icon(Icons.add_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
