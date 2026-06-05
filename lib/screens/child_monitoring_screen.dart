import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../data/models/category_model.dart';
import '../data/models/child_lesson_progress.dart';
import '../data/models/child_session_summary.dart';
import '../data/models/monitored_learner.dart';
import '../data/models/phrase_usage_stat.dart';
import '../data/models/vocabulary_growth_summary.dart';
import '../data/repositories/app_repository.dart';
import '../providers/app_state.dart';
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
  List<ChildLessonProgressEntry> _lessonProgress = [];
  bool _loadingStats = false;
  bool _monthPickerExpanded = false;
  Timer? _liveSessionTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadStats());
    _liveSessionTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (_period == ChildUsagePeriod.today) {
          _reloadSessionSummary();
        }
      },
    );
  }

  @override
  void dispose() {
    _liveSessionTimer?.cancel();
    super.dispose();
  }

  Future<void> _reloadSessionSummary() async {
    if (!mounted) return;
    final app = context.read<AppState>();
    final month = _period == ChildUsagePeriod.month
        ? _resolvedSelectedMonth(_monthOptions())
        : null;
    final summary = await app.getChildSessionSummary(
      learnerUserId: widget.learner.learnerId,
      period: _period,
      month: month,
    );
    if (!mounted) return;
    setState(() => _sessionSummary = summary);
  }

  Future<void> _reloadStats() async {
    final app = context.read<AppState>();
    setState(() => _loadingStats = true);
    final month = _period == ChildUsagePeriod.month
        ? _resolvedSelectedMonth(_monthOptions())
        : null;
    final statsFuture = app.getChildPhraseStats(
      learnerUserId: widget.learner.learnerId,
      period: _period,
      month: month,
    );
    final sessionFuture = app.getChildSessionSummary(
      learnerUserId: widget.learner.learnerId,
      period: _period,
      month: month,
    );
    final vocabularyFuture = app.getChildVocabularyGrowth(
      learnerUserId: widget.learner.learnerId,
      period: _period,
      month: month,
      linkedAt: widget.learner.trackingSince,
    );
    final lessonProgressFuture = app.getChildLessonProgress(
      learnerUserId: widget.learner.learnerId,
      period: _period,
      month: month,
    );
    final categoriesFuture = app.categoriesForUser(widget.learner.learnerId);
    final results = await Future.wait([
      statsFuture,
      sessionFuture,
      vocabularyFuture,
      lessonProgressFuture,
      categoriesFuture,
    ]);
    if (mounted) {
      setState(() {
        _stats = results[0] as List<PhraseUsageStat>;
        _sessionSummary = results[1] as ChildSessionSummary;
        _vocabularyGrowth = results[2] as VocabularyGrowthSummary;
        _lessonProgress = results[3] as List<ChildLessonProgressEntry>;
        _childCategories = results[4] as List<CategoryModel>;
        _loadingStats = false;
      });
    }
  }

  /// Months from link date or up to the last 3 years, through the current month.
  List<DateTime> _monthOptions() {
    final now = DateTime.now();
    final linked = widget.learner.trackingSince;
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

  String _categoryLabel(AppState app, String categoryKey) {
    final normalizedKey = AppRepository.normalizeCategoryKey(categoryKey);
    for (final cat in [..._childCategories, ...app.categories]) {
      if (AppRepository.normalizeCategoryKey(cat.key) == normalizedKey ||
          AppRepository.normalizeCategoryKey(cat.name) == normalizedKey) {
        return app.localizedCategoryName(cat);
      }
    }
    return app.localizedCategoryKey(categoryKey);
  }

  Map<String, List<PhraseUsageStat>> _groupByCategory() {
    final grouped = <String, List<PhraseUsageStat>>{};
    for (final stat in _stats) {
      grouped.putIfAbsent(stat.categoryKey, () => []).add(stat);
    }
    for (final list in grouped.values) {
      list.sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        if (byCount != 0) return byCount;
        return a.text.compareTo(b.text);
      });
    }
    return grouped;
  }

  int _categoryUsageRank(List<PhraseUsageStat> items) {
    var max = 0;
    for (final stat in items) {
      if (stat.count > max) max = stat.count;
    }
    return max;
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
                            onTap: () {
                              setState(() {
                                _selectedMonth = month;
                                _monthPickerExpanded = false;
                              });
                              _reloadStats();
                            },
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
    return Material(
      color: selected ? theme.bgAccent : theme.bgMid.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : theme.textMain,
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
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _periodChip(
              label: AppStrings.today(lang),
              selected: _period == ChildUsagePeriod.today,
              theme: theme,
              onTap: () {
                setState(() {
                  _period = ChildUsagePeriod.today;
                  _monthPickerExpanded = false;
                });
                _reloadStats();
              },
            ),
            _periodChip(
              label: AppStrings.thisWeek(lang),
              selected: _period == ChildUsagePeriod.thisWeek,
              theme: theme,
              onTap: () {
                setState(() {
                  _period = ChildUsagePeriod.thisWeek;
                  _monthPickerExpanded = false;
                });
                _reloadStats();
              },
            ),
            _periodChip(
              label: AppStrings.month(lang),
              selected: _period == ChildUsagePeriod.month,
              theme: theme,
              onTap: () {
                setState(() => _period = ChildUsagePeriod.month);
                _reloadStats();
              },
            ),
          ],
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

  Widget _phraseStatCard({
    required TapTalkThemeToken theme,
    required AppLanguage lang,
    required String phrase,
    required int count,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: const Color(0xFFE9EEF2)),
        boxShadow: [
          BoxShadow(
            color: theme.textMain.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              phrase,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.textMain,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: theme.bgAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              AppStrings.timesUsed(count, lang),
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: theme.bgAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final monthOptions = _monthOptions();
    final selectedMonth = _resolvedSelectedMonth(monthOptions);

    final grouped = _groupByCategory();
    final categoryKeys = grouped.keys.toList()
      ..sort((a, b) {
        final byUsage =
            _categoryUsageRank(grouped[b]!).compareTo(_categoryUsageRank(grouped[a]!));
        if (byUsage != 0) return byUsage;
        return _categoryLabel(app, a).compareTo(_categoryLabel(app, b));
      });

    final contextSubtitle = widget.learner.contextSubtitle;

    return LearnerScaffold(
      title: widget.learner.fullName,
      currentRoute: widget.currentRoute,
      showBackButton: true,
      showBottomNav: false,
      body: ListView(
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
              child: _loadingStats
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : VocabularyGrowthSection(
                      summary: _vocabularyGrowth,
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
              child: _loadingStats
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : LessonProgressSection(
                      entries: _lessonProgress,
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
          if (_loadingStats)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_stats.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Center(
                child: Text(
                  AppStrings.noPhraseUsage(lang),
                  style: GoogleFonts.poppins(
                    color: theme.textMain.withValues(alpha: 0.7),
                  ),
                ),
              ),
            )
          else
            ...categoryKeys.map((categoryKey) {
              final items = grouped[categoryKey]!;
              final categoryLabel = _categoryLabel(app, categoryKey);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    child: Text(
                      categoryLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: theme.textMain,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Column(
                      children: [
                        for (final stat in items)
                          _phraseStatCard(
                            theme: theme,
                            lang: lang,
                            phrase: app.localizedPhrase(
                              stat.text,
                              stat.categoryKey,
                            ),
                            count: stat.count,
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }),
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
              child: _loadingStats
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : SessionUsageChart(
                      summary: _sessionSummary,
                      theme: theme,
                      lang: lang,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
