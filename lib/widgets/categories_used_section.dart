import 'package:flutter/material.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../data/models/category_model.dart';
import '../data/models/vocabulary_growth_summary.dart';
import 'category_usage_pie_chart.dart';

class CategoriesUsedSection extends StatelessWidget {
  const CategoriesUsedSection({
    super.key,
    required this.slices,
    required this.allCategories,
    required this.theme,
    required this.lang,
    required this.labelForCategory,
  });

  final List<CategoryVocabularySlice> slices;
  final List<CategoryModel> allCategories;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final String Function(String categoryKey) labelForCategory;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: CategoryUsagePieChart(
            slices: slices,
            allCategories: allCategories,
            theme: theme,
            lang: lang,
            labelForCategory: labelForCategory,
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Material(
            color: theme.bgMid.withValues(alpha: 0.45),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => CategoryUsagePieChart.showInfoDialog(
                context,
                lang: lang,
                theme: theme,
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: theme.textMain.withValues(alpha: 0.62),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
