class TeacherRecentLesson {
  const TeacherRecentLesson({
    required this.id,
    required this.classId,
    required this.title,
    required this.createdAt,
    required this.phraseCount,
    required this.className,
  });

  final int id;
  final int classId;
  final String title;
  final DateTime createdAt;
  final int phraseCount;
  final String className;
}
