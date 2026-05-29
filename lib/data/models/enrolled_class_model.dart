class EnrolledClassModel {
  const EnrolledClassModel({
    required this.classId,
    required this.className,
    required this.classCode,
    required this.teacherId,
    required this.teacherName,
    required this.enrolledAt,
  });

  final int classId;
  final String className;
  final String classCode;
  final int teacherId;
  final String teacherName;
  final DateTime enrolledAt;

  factory EnrolledClassModel.fromMap(Map<String, Object?> map) {
    return EnrolledClassModel(
      classId: map['class_id'] as int,
      className: map['class_name'] as String,
      classCode: map['class_code'] as String,
      teacherId: map['teacher_id'] as int,
      teacherName: map['teacher_name'] as String,
      enrolledAt: DateTime.fromMillisecondsSinceEpoch(map['enrolled_at'] as int),
    );
  }
}
