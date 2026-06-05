class LessonHistoryContext {
  const LessonHistoryContext({
    required this.className,
    required this.lessonTitle,
  });

  final String className;
  final String lessonTitle;
}

class HistoryModel {
  static const lessonCategoryPrefix = 'lesson:::';

  const HistoryModel({
    required this.id,
    required this.userId,
    required this.text,
    required this.categoryKey,
    required this.createdAt,
    this.className,
    this.lessonTitle,
  });

  final int id;
  final int userId;
  final String text;
  final String categoryKey;
  final DateTime createdAt;
  final String? className;
  final String? lessonTitle;

  static String encodeLessonCategoryKey({
    required String className,
    required String lessonTitle,
  }) {
    return '$lessonCategoryPrefix$className:::$lessonTitle';
  }

  static LessonHistoryContext? decodeLessonCategoryKey(String categoryKey) {
    if (!categoryKey.startsWith(lessonCategoryPrefix)) return null;
    final rest = categoryKey.substring(lessonCategoryPrefix.length);
    final separator = rest.indexOf(':::');
    if (separator <= 0) return null;
    final decodedClass = rest.substring(0, separator).trim();
    final decodedLesson = rest.substring(separator + 3).trim();
    if (decodedClass.isEmpty || decodedLesson.isEmpty) return null;
    return LessonHistoryContext(
      className: decodedClass,
      lessonTitle: decodedLesson,
    );
  }

  LessonHistoryContext? get lessonContext {
    if (className != null &&
        className!.trim().isNotEmpty &&
        lessonTitle != null &&
        lessonTitle!.trim().isNotEmpty) {
      return LessonHistoryContext(
        className: className!.trim(),
        lessonTitle: lessonTitle!.trim(),
      );
    }
    return decodeLessonCategoryKey(categoryKey);
  }

  bool get isLessonEntry => lessonContext != null;

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'phrase_text': text,
        'category_key': categoryKey,
        'created_at': createdAt.millisecondsSinceEpoch,
        'class_name': className,
        'lesson_title': lessonTitle,
      };

  factory HistoryModel.fromMap(Map<String, Object?> map) {
    return HistoryModel(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      text: map['phrase_text'] as String,
      categoryKey: map['category_key'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      className: map['class_name'] as String?,
      lessonTitle: map['lesson_title'] as String?,
    );
  }
}
