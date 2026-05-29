class TeacherClassStudent {
  const TeacherClassStudent({
    required this.learnerId,
    required this.fullName,
    required this.classId,
    required this.className,
    required this.classCode,
    required this.enrolledAt,
  });

  final int learnerId;
  final String fullName;
  final int classId;
  final String className;
  final String classCode;
  final DateTime enrolledAt;
}
