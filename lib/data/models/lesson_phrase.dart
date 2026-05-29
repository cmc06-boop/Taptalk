class LessonPhrase {
  const LessonPhrase({
    required this.id,
    required this.lessonId,
    required this.text,
    this.imagePath,
  });

  final int id;
  final int lessonId;
  final String text;
  final String? imagePath;
}
