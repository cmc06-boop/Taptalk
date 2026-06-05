class ChildLessonProgressEntry {
  const ChildLessonProgressEntry({
    required this.className,
    required this.lessonTitle,
    required this.practicedPhrases,
    required this.totalInteractions,
    required this.lastAccessed,
    this.totalPhrases,
  });

  final String className;
  final String lessonTitle;
  final int practicedPhrases;
  final int totalInteractions;
  final DateTime? lastAccessed;
  final int? totalPhrases;

  double? get progressFraction {
    final total = totalPhrases;
    if (total == null || total <= 0) return null;
    return (practicedPhrases / total).clamp(0.0, 1.0);
  }

  int get progressPercent {
    final fraction = progressFraction;
    if (fraction == null) return 0;
    return (fraction * 100).round();
  }
}
