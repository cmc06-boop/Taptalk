class TeacherNegativeUsageWarning {
  const TeacherNegativeUsageWarning({
    required this.childName,
    required this.phraseText,
    required this.count,
    this.level = 1,
    this.title = '',
    this.body = '',
  });

  final String childName;
  final String phraseText;
  final int count;
  final int level;
  final String title;
  final String body;
}
