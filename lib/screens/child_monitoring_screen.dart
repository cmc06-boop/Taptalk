import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../core/utils/vocabulary_growth_calculator.dart';
import '../data/models/category_model.dart';
import '../data/models/child_session_summary.dart';
import '../data/models/monitored_learner.dart';
import '../data/models/phrase_usage_stat.dart';
import '../data/models/vocabulary_growth_summary.dart';
import '../data/repositories/app_repository.dart';
import '../providers/app_state.dart';
import '../widgets/categories_used_section.dart';
import '../widgets/frequently_used_section.dart';
import '../widgets/learner_scaffold.dart';
import '../widgets/lesson_progress_section.dart';
import '../widgets/session_usage_chart.dart';
import '../widgets/vocabulary_growth_section.dart';

class ChildMonitoringScreen extends StatefulWidget {
  const ChildMonitoringScreen({
    super.key,
    required this.learner,
    this.currentRoute = AppRoute.myChild,
  });

  final MonitoredLearner learner;
  final AppRoute currentRoute;

  @override
  State<ChildMonitoringScreen> createState() => _ChildMonitoringScreenState();
}

class _ChildMonitoringScreenState extends State<ChildMonitoringScreen> {
  static const _cardRadius = 14.0;

  ChildUsagePeriod _period = ChildUsagePeriod.today;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<PhraseUsageStat> _stats = [];
  List<CategoryModel> _childCategories = [];
  ChildSessionSummary _sessionSummary = ChildSessionSummary.empty;
  VocabularyGrowthSummary _vocabularyGrowth = VocabularyGrowthSummary.empty;
  bool _refreshing = false;
  int _reloadNonce = 0;
  bool _monthPickerExpanded = false;
  DateTime? _trackingSince;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLocalStats());
  }

  Future<void> _loadLocalStats() async {
    final app = context.read<AppState>();
    try {
      final trackingSince = await app.getLearnerMonitoringSince(
        widget.learner.learnerId,
      );
      final month = _period == ChildUsagePeriod.month
          ? _resolvedSelectedMonth(_monthOptions(trackingSince))
          : null;
      final results = await Future.wait([
        app.getChildPhraseStats(
          learnerUserId: widget.learner.learnerId,
          period: _period,
          month: month,
        ),
        app.getChildSessionSummary(
          learnerUserId: widget.learner.learnerId,
          period: _period,
          month: month,
        ),
        app.getChildVocabularyGrowth(
          learnerUserId: widget.learner.learnerId,
          period: _period,
          month: month,
          linkedAt: trackingSince,
        ),
        app.getCategoriesForMonitoring(widget.learner.learnerId),
      ]);
      if (!mounted) return;
      setState(() {
        _trackingSince = trackingSince;
        _stats = results[0] as List<PhraseUsageStat>;
        _sessionSummary = results[1] as ChildSessionSummary;
        _vocabularyGrowth = results[2] as VocabularyGrowthSummary;
        _childCategories = results[3] as List<CategoryModel>;
        _reloadNonce++;
      });
    } catch (e, st) {
      debugPrint('Monitoring stats load failed: $e\n$st');
    }
  }

  Future<void> _refreshFromCloud() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await context
          .read<AppState>()
          .refreshChildMonitoringData(widget.learner.learnerId);
      await _loadLocalStats();
    } catch (e, st) {
      debugPrint('Monitoring cloud refresh failed: $e\n$st');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  /// Months from link date or up to the last 3 years, through the current month.
  List<DateTime> _monthOptions([DateTime? trackingSince]) {
    final now = DateTime.now();
    final linked = trackingSince ?? _trackingSince ?? widget.learner.trackingSince;
    final linkedStart = DateTime(linked.year, linked.month);
    final threeYearsBack = DateTime(now.year - 3, now.month);
    final start =
        linkedStart.isBefore(threeYearsBack) ? linkedStart : threeYearsBack;
    final end = DateTime(now.year, now.month);

    final months = <DateTime>[];
    var cursor = end;
    while (true) {
      months.add(cursor);
      if (cursor.year == start.year && cursor.month == start.month) break;
      cursor = DateTime(cursor.year, cursor.month - 1);
    }
    return months;
  }

  DateTime _resolvedSelectedMonth(List<DateTime> options) {
    if (options.isEmpty) return _selectedMonth;
    final match = options.any(
      (m) => m.year == _selectedMonth.year && m.month == _selectedMonth.month,
    );
    return match ? _selectedMonth : options.first;
  }

  String _formatMonth(DateTime month, AppLanguage lang) {
    return DateFormat.yMMMM(
      lang == AppLanguage.filipino ? 'fil_PH' : 'en_US',
    ).format(month);
  }

  String _periodLabel(AppLanguage lang, DateTime selectedMonth) {
    switch (_period) {
      case ChildUsagePeriod.today:
        return AppStrings.today(lang);
      case ChildUsagePeriod.thisWeek:
        return AppStrings.thisWeek(lang);
      case ChildUsagePeriod.month:
        return _formatMonth(selectedMonth, lang);
    }
  }

  int get _periodPhraseTaps =>
      _stats.fold<int>(0, (sum, stat) => sum + stat.count);

  int get _periodPhrasesUsed {
    final seen = <String>{};
    for (final stat in _stats) {
      seen.add('${stat.categoryKey}|${stat.text}');
    }
    return seen.length;
  }

  /// For Me usage per category (defaults + custom) from speak history.
  List<CategoryVocabularySlice> get _categoryUsageSlices =>
      VocabularyGrowthCalculator.categorySlicesFromPhraseStats(_stats);

  void _selectPeriod(ChildUsagePeriod period) {
    if (_period == period && period != ChildUsagePeriod.month) return;
    setState(() {
      _period = period;
      _monthPickerExpanded = false;
    });
    _loadLocalStats();
  }

  void _selectMonth(DateTime month) {
    setState(() {
      _selectedMonth = month;
      _monthPickerExpanded = false;
    });
    _loadLocalStats();
  }

  String _categoryLabel(AppState app, String categoryKey) {
    final normalizedKey = AppRepository.normalizeCategoryKey(categoryKey);
    for (final cat in _childCategories) {
      if (AppRepository.normalizeCategoryKey(cat.key) == normalizedKey ||
          AppRepository.normalizeCategoryKey(cat.name) == normalizedKey) {
        return app.localizedCategoryName(cat);
      }
    }
    return app.localizedCategoryKey(categoryKey);
  }

  Widget _buildExpandableMonthPicker({
    required TapTalkThemeToken theme,
    required AppLanguage lang,
    required List<DateTime> monthOptions,
    required DateTime selectedMonth,
  }) {
    const animDuration = Duration(milliseconds: 280);
    const animCurve = Curves.easeInOutCubic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_cardRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => setState(() => _monthPickerExpanded = !_monthPickerExpanded),
            borderRadius: BorderRadius.circular(_cardRadius),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_cardRadius),
                border: Border.all(
                  color: _monthPickerExpanded
                      ? theme.bgAccent.withValues(alpha: 0.55)
                      : const Color(0xFFE9EEF2),
                  width: _monthPickerExpanded ? 1.4 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.selectMonthPeriod(lang),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.textMain.withValues(alpha: 0.65),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatMonth(selectedMonth, lang),
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: theme.textMain,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    duration: animDuration,
                    curve: animCurve,
                    turns: _monthPickerExpanded ? 0.5 : 0,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: theme.bgAccent,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: animDuration,
          curve: animCurve,
          alignment: Alignment.topCenter,
          clipBehavior: Clip.hardEdge,
          child: _monthPickerExpanded
              ? Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_cardRadius),
                    border: Border.all(color: const Color(0xFFE9EEF2)),
                    boxShadow: [
                      BoxShadow(
                        color: theme.textMain.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      itemCount: monthOptions.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        indent: AppSpacing.md,
                        endIndent: AppSpacing.md,
                        color: theme.textMain.withValues(alpha: 0.08),
                      ),
                      itemBuilder: (context, index) {
                        final month = monthOptions[index];
                        final isSelected = month.year == selectedMonth.year &&
                            month.month == selectedMonth.month;
                        return Material(
                          color: isSelected
                              ? theme.bgAccent.withValues(alpha: 0.10)
                              : Colors.transparent,
                          child: InkWell(
                            onTap: () => _selectMonth(month),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm + 2,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _formatMonth(month, lang),
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? theme.bgAccent
                                            : theme.textMain,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_rounded,
                                      size: 20,
                                      color: theme.bgAccent,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _periodChip({
    required String label,
    required bool selected,
    required TapTalkThemeToken theme,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected
              ? theme.bgAccent
              : theme.textMain.withValues(alpha: 0.12),
          width: selected ? 1.5 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: theme.bgAccent.withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: selected ? theme.bgAccent : theme.bgMid.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs + 2,
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : theme.textMain,
                height: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodFilterBar({
    required TapTalkThemeToken theme,
    required AppLanguage lang,
    required List<DateTime> monthOptions,
    required DateTime selectedMonth,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            _periodChip(
              label: AppStrings.today(lang),
              selected: _period == ChildUsagePeriod.today,
              theme: theme,
              onTap: () => _selectPeriod(ChildUsagePeriod.today),
            ),
            _periodChip(
              label: AppStrings.thisWeek(lang),
              selected: _period == ChildUsagePeriod.thisWeek,
              theme: theme,
              onTap: () => _selectPeriod(ChildUsagePeriod.thisWeek),
            ),
            _periodChip(
              label: AppStrings.month(lang),
              selected: _period == ChildUsagePeriod.month,
              theme: theme,
              onTap: () => _selectPeriod(ChildUsagePeriod.month),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          AppStrings.monitoringShowingPeriod(
            lang,
            _periodLabel(lang, selectedMonth),
          ),
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: theme.textMain.withValues(alpha: 0.58),
            height: 1.3,
          ),
        ),
        if (_period == ChildUsagePeriod.month) ...[
          const SizedBox(height: AppSpacing.sm),
          _buildExpandableMonthPicker(
            theme: theme,
            lang: lang,
            monthOptions: monthOptions,
            selectedMonth: selectedMonth,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final monthOptions = _monthOptions(_trackingSince);
    final selectedMonth = _resolvedSelectedMonth(monthOptions);

    final contextSubtitle = widget.learner.contextSubtitle;

    return LearnerScaffold(
      title: widget.learner.fullName,
      currentRoute: widget.currentRoute,
      showBackButton: true,
      showBottomNav: false,
      body: RefreshIndicator(
        onRefresh: _refreshFromCloud,
        child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          if (contextSubtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
              child: Text(
                contextSubtitle,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.textMain.withValues(alpha: 0.65),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: _buildPeriodFilterBar(
              theme: theme,
              lang: lang,
              monthOptions: monthOptions,
              selectedMonth: selectedMonth,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              AppStrings.vocabularyGrowth(lang),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: theme.textMain,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_cardRadius),
                border: Border.all(color: const Color(0xFFE9EEF2)),
              ),
              child: VocabularyGrowthSection(
                      key: ValueKey(
                        'vocab_${_period.name}_$_reloadNonce',
                      ),
                      summary: _vocabularyGrowth,
                      theme: theme,
                      lang: lang,
                      phrasesUsed: _periodPhrasesUsed,
                      phraseTaps: _periodPhraseTaps,
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              AppStrings.categoriesUsed(lang),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: theme.textMain,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_cardRadius),
                border: Border.all(color: const Color(0xFFE9EEF2)),
              ),
              child: CategoriesUsedSection(
                      key: ValueKey(
                        'categories_${_period.name}_$_reloadNonce',
                      ),
                      slices: _categoryUsageSlices,
                      allCategories: _childCategories,
                      theme: theme,
                      lang: lang,
                      labelForCategory: (key) => _categoryLabel(app, key),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              AppStrings.lessonProgress(lang),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: theme.textMain,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_cardRadius),
                border: Border.all(color: const Color(0xFFE9EEF2)),
              ),
              child: LessonProgressSection(
                learnerUserId: widget.learner.learnerId,
                period: _period,
                month: _period == ChildUsagePeriod.month
                    ? _resolvedSelectedMonth(_monthOptions(_trackingSince))
                    : null,
                reloadNonce: _reloadNonce,
                syncCloudOnReload: true,
                theme: theme,
                lang: lang,
                labelForContent: app.localizedContent,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              AppStrings.frequentlyUsed(lang),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: theme.textMain,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_cardRadius),
                border: Border.all(color: const Color(0xFFE9EEF2)),
              ),
              child: FrequentlyUsedSection(
                      key: ValueKey(
                        'frequent_${_period.name}_$_reloadNonce',
                      ),
                      stats: _stats,
                      theme: theme,
                      lang: lang,
                      reloadNonce: _reloadNonce,
                      allowedCategoryKeys: _childCategories
                          .map((c) => AppRepository.normalizeCategoryKey(c.key))
                          .toSet(),
                      labelForCategory: (key) => _categoryLabel(app, key),
                      labelForPhrase: (stat) => app.localizedPhrase(
                        stat.text,
                        stat.categoryKey,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              AppStrings.sessionActivity(lang),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: theme.textMain,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              AppStrings.sessionActivitySubtitle(lang),
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: theme.textMain.withValues(alpha: 0.62),
                height: 1.35,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_cardRadius),
                border: Border.all(color: const Color(0xFFE9EEF2)),
              ),
              child: SessionUsageChart(
                      key: ValueKey(
                        'sessions_${_period.name}_$_reloadNonce',
                      ),
                      summary: _sessionSummary,
                      theme: theme,
                      lang: lang,
                    ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
