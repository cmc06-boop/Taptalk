import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../core/utils/vocabulary_growth_calculator.dart';
import '../data/models/category_model.dart';
import '../data/models/vocabulary_growth_summary.dart';
import 'category_usage_pie_chart.dart';
import 'vocabulary_growth_chart.dart';

class VocabularyGrowthSection extends StatefulWidget {
  const VocabularyGrowthSection({
    super.key,
    required this.summary,
    required this.allCategories,
    required this.theme,
    required this.lang,
    required this.labelForCategory,
  });

  final VocabularyGrowthSummary summary;
  final List<CategoryModel> allCategories;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final String Function(String categoryKey) labelForCategory;

  @override
  State<VocabularyGrowthSection> createState() => _VocabularyGrowthSectionState();
}

class _VocabularyGrowthSectionState extends State<VocabularyGrowthSection> {
  VocabularyTrendGranularity _granularity = VocabularyTrendGranularity.weeks;
  bool _showCumulative = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final lang = widget.lang;
    final summary = widget.summary;
    final trend = _granularity == VocabularyTrendGranularity.weeks
        ? summary.weeklyTrend
        : summary.monthlyTrend;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppStrings.vocabularyGrowthSubtitle(lang),
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: theme.textMain.withValues(alpha: 0.62),
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _StatRow(
          theme: theme,
          lang: lang,
          total: summary.totalVocabulary,
          weekNew: summary.newWordsThisWeek,
          monthNew: summary.newWordsThisMonth,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          AppStrings.newWordsTrend(lang),
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: theme.textMain,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            _ToggleChip(
              label: AppStrings.trendByWeek(lang),
              selected: _granularity == VocabularyTrendGranularity.weeks,
              theme: theme,
              onTap: () => setState(
                () => _granularity = VocabularyTrendGranularity.weeks,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _ToggleChip(
              label: AppStrings.trendByMonth(lang),
              selected: _granularity == VocabularyTrendGranularity.months,
              theme: theme,
              onTap: () => setState(
                () => _granularity = VocabularyTrendGranularity.months,
              ),
            ),
            const Spacer(),
            _ToggleChip(
              label: lang == AppLanguage.filipino ? 'Kabuuan' : 'Total',
              selected: _showCumulative,
              theme: theme,
              compact: true,
              onTap: () => setState(() => _showCumulative = !_showCumulative),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        VocabularyGrowthChart(
          points: trend,
          theme: theme,
          lang: lang,
          showCumulative: _showCumulative,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          AppStrings.categoriesUsed(lang),
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: theme.textMain,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        CategoryUsagePieChart(
          slices: summary.categorySlices,
          allCategories: widget.allCategories,
          theme: theme,
          lang: lang,
          labelForCategory: widget.labelForCategory,
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.theme,
    required this.lang,
    required this.total,
    required this.weekNew,
    required this.monthNew,
  });

  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final int total;
  final int weekNew;
  final int monthNew;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            theme: theme,
            label: AppStrings.totalVocabulary(lang),
            value: '$total',
            highlight: true,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            theme: theme,
            label: AppStrings.newWordsThisWeek(lang),
            value: '+$weekNew',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatCard(
            theme: theme,
            label: AppStrings.newWordsThisMonth(lang),
            value: '+$monthNew',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.theme,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final TapTalkThemeToken theme;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: highlight
            ? theme.bgAccent.withValues(alpha: 0.12)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? theme.bgAccent.withValues(alpha: 0.35)
              : const Color(0xFFE9EEF2),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: theme.textMain.withValues(alpha: 0.62),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: highlight ? theme.bgAccent : theme.textMain,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.theme,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final TapTalkThemeToken theme;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? theme.bgAccent.withValues(alpha: 0.16)
          : theme.bgMid.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.sm : AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? theme.bgAccent : theme.textMain,
            ),
          ),
        ),
      ),
    );
  }
}
