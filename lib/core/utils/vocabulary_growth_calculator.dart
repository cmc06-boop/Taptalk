import 'package:intl/intl.dart';

import '../../data/models/phrase_first_use.dart';
import '../../data/models/phrase_usage_stat.dart';
import '../../data/models/vocabulary_growth_summary.dart';
import '../../data/repositories/app_repository.dart';
import '../constants/child_usage_period.dart';
import 'session_usage_calculator.dart';

typedef _TrendBuckets = ({
  List<String> labels,
  List<String> details,
  List<int> counts,
});

/// Builds vocabulary growth metrics from learner-added custom phrases.
abstract final class VocabularyGrowthCalculator {
  static VocabularyGrowthSummary summarize({
    required List<PhraseFirstUse> firstUses,
    required ChildUsagePeriod period,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required String localeName,
    List<CategoryVocabularySlice>? periodCategorySlices,
  }) {
    final hasPeriodSlices =
        periodCategorySlices != null && periodCategorySlices.isNotEmpty;
    if (firstUses.isEmpty && !hasPeriodSlices) {
      return VocabularyGrowthSummary.empty;
    }

    final periodEntries = firstUses
        .where(
          (entry) =>
              !entry.firstUsedAt.isBefore(rangeStart) &&
              entry.firstUsedAt.isBefore(rangeEnd),
        )
        .toList();

    final trend = _buildTrend(
      entries: periodEntries,
      period: period,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      localeName: localeName,
    );

    final categorySlices = periodCategorySlices ??
        _categorySlicesFromFirstUses(firstUses);

    final totalVocabulary = firstUses.isEmpty
        ? categorySlices.fold<int>(0, (sum, s) => sum + s.wordCount)
        : firstUses.length;

    return VocabularyGrowthSummary(
      totalVocabulary: totalVocabulary,
      trend: trend,
      categorySlices: categorySlices,
    );
  }

  /// Usage-based category breakdown from speak history (defaults + custom).
  static List<CategoryVocabularySlice> categorySlicesFromPhraseStats(
    List<PhraseUsageStat> stats,
  ) {
    final usageByCategory = <String, int>{};
    final wordsByCategory = <String, int>{};
    final seenInPeriod = <String>{};
    for (final stat in stats) {
      if (!AppRepository.isPersonalCategoryKey(stat.categoryKey)) continue;
      usageByCategory.update(
        stat.categoryKey,
        (v) => v + stat.count,
        ifAbsent: () => stat.count,
      );
      final key = '${stat.categoryKey}|${stat.text}';
      if (seenInPeriod.add(key)) {
        wordsByCategory.update(
          stat.categoryKey,
          (v) => v + 1,
          ifAbsent: () => 1,
        );
      }
    }
    return categorySlicesFromUsage(
      usageByCategory: usageByCategory,
      wordsByCategory: wordsByCategory,
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

  /// Buckets new phrases across the selected period so the chart axis matches
  /// the Today / This week / Month filter instead of a fixed trailing window.
  static List<VocabularyGrowthPoint> _buildTrend({
    required List<PhraseFirstUse> entries,
    required ChildUsagePeriod period,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required String localeName,
  }) {
    final bucketed = switch (period) {
      ChildUsagePeriod.today => _bucketByHour(entries),
      ChildUsagePeriod.thisWeek => _bucketByDay(
          entries,
          rangeStart,
          rangeEnd,
          localeName,
        ),
      ChildUsagePeriod.month => _bucketByWeek(
          entries,
          rangeStart,
          rangeEnd,
          localeName,
        ),
    };

    if (bucketed.counts.every((count) => count == 0)) {
      return const <VocabularyGrowthPoint>[];
    }
    return _toTrendPoints(
      labels: bucketed.labels,
      details: bucketed.details,
      newCounts: bucketed.counts,
    );
  }

  static _TrendBuckets _bucketByHour(List<PhraseFirstUse> entries) {
    final counts = List<int>.filled(24, 0);
    for (final entry in entries) {
      counts[entry.firstUsedAt.hour.clamp(0, 23)]++;
    }
    final details = List<String>.generate(
      24,
      SessionUsageCalculator.hourLabelAmPm,
    );
    final labels = List<String>.generate(24, (hour) {
      final showLabel = hour == 0 || hour == 6 || hour == 12 || hour == 18;
      return showLabel ? details[hour] : '';
    });
    return (labels: labels, details: details, counts: counts);
  }

  static _TrendBuckets _bucketByDay(
    List<PhraseFirstUse> entries,
    DateTime rangeStart,
    DateTime rangeEnd,
    String localeName,
  ) {
    final dayCount = rangeEnd.difference(rangeStart).inDays.clamp(1, 31);
    final counts = List<int>.filled(dayCount, 0);
    for (final entry in entries) {
      final index = _dayOffset(entry.firstUsedAt, rangeStart)
          .clamp(0, dayCount - 1);
      counts[index]++;
    }
    final labelFormat = DateFormat('EEE', localeName);
    final detailFormat = DateFormat('EEE, MMM d', localeName);
    final labels = <String>[];
    final details = <String>[];
    for (var index = 0; index < dayCount; index++) {
      final day = rangeStart.add(Duration(days: index));
      labels.add(labelFormat.format(day));
      details.add(detailFormat.format(day));
    }
    return (labels: labels, details: details, counts: counts);
  }

  static _TrendBuckets _bucketByWeek(
    List<PhraseFirstUse> entries,
    DateTime rangeStart,
    DateTime rangeEnd,
    String localeName,
  ) {
    final dayCount = rangeEnd.difference(rangeStart).inDays;
    final weekCount = (dayCount / 7).ceil().clamp(1, 6);
    final counts = List<int>.filled(weekCount, 0);
    for (final entry in entries) {
      final index = (_dayOffset(entry.firstUsedAt, rangeStart) ~/ 7)
          .clamp(0, weekCount - 1);
      counts[index]++;
    }
    final startFormat = DateFormat.MMMd(localeName);
    final endFormat = DateFormat.d(localeName);
    final labels = <String>[];
    final details = <String>[];
    for (var week = 0; week < weekCount; week++) {
      final firstOffset = week * 7;
      final lastOffset = firstOffset + 6 >= dayCount
          ? dayCount - 1
          : firstOffset + 6;
      final start = rangeStart.add(Duration(days: firstOffset));
      final end = rangeStart.add(Duration(days: lastOffset));
      labels.add('Week ${week + 1}');
      details.add(
        '${startFormat.format(start)}\u2013${endFormat.format(end)}',
      );
    }
    return (labels: labels, details: details, counts: counts);
  }

  static int _dayOffset(DateTime date, DateTime rangeStart) {
    final day = DateTime(date.year, date.month, date.day);
    return day.difference(rangeStart).inDays;
  }

  static List<VocabularyGrowthPoint> _toTrendPoints({
    required List<String> labels,
    required List<String> details,
    required List<int> newCounts,
  }) {
    var running = 0;
    return List.generate(labels.length, (i) {
      running += newCounts[i];
      return VocabularyGrowthPoint(
        label: labels[i],
        detail: details[i],
        newWords: newCounts[i],
        cumulativeWords: running,
      );
    });
  }
}
