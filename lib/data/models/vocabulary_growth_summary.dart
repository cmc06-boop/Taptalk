class VocabularyGrowthPoint {
  const VocabularyGrowthPoint({
    required this.label,
    required this.newWords,
    required this.cumulativeWords,
  });

  final String label;
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
    required this.newWordsThisWeek,
    required this.newWordsThisMonth,
    required this.weeklyTrend,
    required this.monthlyTrend,
    required this.categorySlices,
  });

  final int totalVocabulary;
  final int newWordsThisWeek;
  final int newWordsThisMonth;
  final List<VocabularyGrowthPoint> weeklyTrend;
  final List<VocabularyGrowthPoint> monthlyTrend;
  final List<CategoryVocabularySlice> categorySlices;

  static const empty = VocabularyGrowthSummary(
    totalVocabulary: 0,
    newWordsThisWeek: 0,
    newWordsThisMonth: 0,
    weeklyTrend: [],
    monthlyTrend: [],
    categorySlices: [],
  );
}
