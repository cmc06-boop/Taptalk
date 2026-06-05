import 'package:intl/intl.dart';

import '../../data/models/phrase_first_use.dart';
import '../../data/models/vocabulary_growth_summary.dart';

enum VocabularyTrendGranularity { weeks, months }

/// Builds vocabulary growth metrics from each phrase's first history entry.
abstract final class VocabularyGrowthCalculator {
  static const _weekBucketCount = 8;
  static const _monthBucketCount = 6;

  static VocabularyGrowthSummary summarize({
    required List<PhraseFirstUse> firstUses,
    required DateTime now,
    required DateTime rangeStart,
    required String localeName,
    List<CategoryVocabularySlice>? periodCategorySlices,
  }) {
    final hasPeriodSlices =
        periodCategorySlices != null && periodCategorySlices.isNotEmpty;
    if (firstUses.isEmpty && !hasPeriodSlices) {
      return VocabularyGrowthSummary.empty;
    }

    final weekStart = _startOfWeek(now);
    final monthStart = DateTime(now.year, now.month);

    var newThisWeek = 0;
    var newThisMonth = 0;
    for (final entry in firstUses) {
      if (!entry.firstUsedAt.isBefore(weekStart)) newThisWeek++;
      if (!entry.firstUsedAt.isBefore(monthStart)) newThisMonth++;
    }

    final weeklyTrend = firstUses.isEmpty
        ? const <VocabularyGrowthPoint>[]
        : _buildWeeklyTrend(
            firstUses: firstUses,
            now: now,
            rangeStart: rangeStart,
            localeName: localeName,
          );
    final monthlyTrend = firstUses.isEmpty
        ? const <VocabularyGrowthPoint>[]
        : _buildMonthlyTrend(
            firstUses: firstUses,
            now: now,
            rangeStart: rangeStart,
            localeName: localeName,
          );

    final categorySlices = periodCategorySlices ??
        _categorySlicesFromFirstUses(firstUses);

    final totalVocabulary = firstUses.isEmpty
        ? categorySlices.fold<int>(0, (sum, s) => sum + s.wordCount)
        : firstUses.length;

    return VocabularyGrowthSummary(
      totalVocabulary: totalVocabulary,
      newWordsThisWeek: newThisWeek,
      newWordsThisMonth: newThisMonth,
      weeklyTrend: weeklyTrend,
      monthlyTrend: monthlyTrend,
      categorySlices: categorySlices,
    );
  }

  static List<CategoryVocabularySlice> categorySlicesFromUsage({
    required Map<String, int> usageByCategory,
    required Map<String, int> wordsByCategory,
  }) {
    final keys = {...usageByCategory.keys, ...wordsByCategory.keys};
    final slices = keys
        .map(
          (key) => CategoryVocabularySlice(
            categoryKey: key,
            wordCount: wordsByCategory[key] ?? 0,
            usageCount: usageByCategory[key] ?? 0,
          ),
        )
        .toList()
      ..sort((a, b) {
        final byUsage = b.usageCount.compareTo(a.usageCount);
        if (byUsage != 0) return byUsage;
        return b.wordCount.compareTo(a.wordCount);
      });
    return slices;
  }

  static List<CategoryVocabularySlice> _categorySlicesFromFirstUses(
    List<PhraseFirstUse> firstUses,
  ) {
    final wordsByCategory = <String, int>{};
    for (final entry in firstUses) {
      wordsByCategory.update(
        entry.categoryKey,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    return categorySlicesFromUsage(
      usageByCategory: wordsByCategory,
      wordsByCategory: wordsByCategory,
    );
  }

  static List<VocabularyGrowthPoint> _buildWeeklyTrend({
    required List<PhraseFirstUse> firstUses,
    required DateTime now,
    required DateTime rangeStart,
    required String localeName,
  }) {
    final endWeek = _startOfWeek(now);
    final buckets = <DateTime>[];
    for (var i = _weekBucketCount - 1; i >= 0; i--) {
      buckets.add(endWeek.subtract(Duration(days: 7 * i)));
    }

    final labelFormat = DateFormat.MMMd(localeName);
    final counts = List<int>.filled(buckets.length, 0);
    for (final entry in firstUses) {
      if (entry.firstUsedAt.isBefore(rangeStart)) continue;
      final week = _startOfWeek(entry.firstUsedAt);
      final index = buckets.indexWhere(
        (b) => b.year == week.year && b.month == week.month && b.day == week.day,
      );
      if (index >= 0) counts[index]++;
    }

    return _toTrendPoints(
      labels: buckets.map((b) => labelFormat.format(b)).toList(),
      newCounts: counts,
    );
  }

  static List<VocabularyGrowthPoint> _buildMonthlyTrend({
    required List<PhraseFirstUse> firstUses,
    required DateTime now,
    required DateTime rangeStart,
    required String localeName,
  }) {
    final endMonth = DateTime(now.year, now.month);
    final buckets = <DateTime>[];
    for (var i = _monthBucketCount - 1; i >= 0; i--) {
      buckets.add(DateTime(endMonth.year, endMonth.month - i));
    }

    final labelFormat = DateFormat.MMM(localeName);
    final counts = List<int>.filled(buckets.length, 0);
    for (final entry in firstUses) {
      if (entry.firstUsedAt.isBefore(rangeStart)) continue;
      final month = DateTime(entry.firstUsedAt.year, entry.firstUsedAt.month);
      final index = buckets.indexWhere(
        (b) => b.year == month.year && b.month == month.month,
      );
      if (index >= 0) counts[index]++;
    }

    return _toTrendPoints(
      labels: buckets.map((b) => labelFormat.format(b)).toList(),
      newCounts: counts,
    );
  }

  static List<VocabularyGrowthPoint> _toTrendPoints({
    required List<String> labels,
    required List<int> newCounts,
  }) {
    var running = 0;
    return List.generate(labels.length, (i) {
      running += newCounts[i];
      return VocabularyGrowthPoint(
        label: labels[i],
        newWords: newCounts[i],
        cumulativeWords: running,
      );
    });
  }

  static DateTime _startOfWeek(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }
}
