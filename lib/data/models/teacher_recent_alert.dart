import 'parent_notification.dart';

class TeacherRecentAlert {
  const TeacherRecentAlert({
    required this.id,
    required this.classId,
    required this.childName,
    required this.alertType,
    required this.className,
    required this.createdAt,
  });

  final int id;
  final int classId;
  final String childName;
  final ParentAlertType alertType;
  final String className;
  final DateTime createdAt;
}
