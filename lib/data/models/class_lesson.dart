class ClassLesson {
  const ClassLesson({
    required this.id,
    required this.classId,
    required this.title,
    required this.createdAt,
    this.phraseCount = 0,
  });

  final int id;
  final int classId;
  final String title;
  final DateTime createdAt;
  final int phraseCount;
}
