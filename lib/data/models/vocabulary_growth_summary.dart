class VocabularyGrowthPoint {
  const VocabularyGrowthPoint({
    required this.label,
    required this.detail,
    required this.newWords,
    required this.cumulativeWords,
  });

  /// Short axis label, e.g. 'Week 1', 'Mon', '6 AM'.
  final String label;

  /// Full span this bucket covers, shown when the point is tapped.
  final String detail;
  final int newWords;
  final int cumulativeWords;
}

class CategoryVocabularySlice {
  const CategoryVocabularySlice({
    required this.categoryKey,
    required this.wordCount,
    required this.usageCount,
  });

  final String categoryKey;
  final int wordCount;
  final int usageCount;
}

class VocabularyGrowthSummary {
  const VocabularyGrowthSummary({
    required this.totalVocabulary,
    required this.trend,
    required this.categorySlices,
  });

  final int totalVocabulary;

  /// New-phrase buckets for the selected monitoring period.
  final List<VocabularyGrowthPoint> trend;
  final List<CategoryVocabularySlice> categorySlices;

  static const empty = VocabularyGrowthSummary(
    totalVocabulary: 0,
    trend: [],
    categorySlices: [],
  );
}

/// Stats for the monitoring vocabulary growth panel (first section).
class VocabularyGrowthPanelData {
  const VocabularyGrowthPanelData({
    required this.summary,
    required this.phrasesUsed,
    required this.phraseTaps,
  });

  final VocabularyGrowthSummary summary;
  final int phrasesUsed;
  final int phraseTaps;

  static const empty = VocabularyGrowthPanelData(
    summary: VocabularyGrowthSummary.empty,
    phrasesUsed: 0,
    phraseTaps: 0,
  );
}
