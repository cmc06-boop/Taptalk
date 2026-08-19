import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';
import '../widgets/add_category_dialog.dart';
import '../widgets/category_grid_card.dart';
import '../widgets/taptalk_shell.dart';

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
    final name = app.user?.fullName ?? AppStrings.defaultLearnerName(lang);
    final categoryColumns = AppSpacing.categoryGridColumns(context);

    return TapTalkShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md + MediaQuery.paddingOf(context).top,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppStrings.chooseCategoryTitle(lang),
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: theme.textMain,
                  ),
                ),
                TextButton(
                  onPressed: () => _showAddCategoryDialog(context),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: BorderSide(
                        color: theme.bgAccent.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  child: Text(
                    AppStrings.addCategoryShort(lang),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      color: theme.bgAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: const Color(0xFFE9EEF2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.hiUser(name, lang),
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
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: categoryColumns,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: categoryColumns >= 5 ? 0.92 : 0.82,
              ),
              itemCount: app.topLevelCategories.length,
              itemBuilder: (context, i) {
                final cat = app.topLevelCategories[i];
                return CategoryGridCard(
                  category: cat,
                  label: app.localizedCategoryName(cat),
                  onTap: () => app.completeCategorySelection(cat.key),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
