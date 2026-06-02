enum TeacherAlertStatus {
  sent,
  noLinkedParents,
  notAuthorized,
}

class TeacherAlertResult {
  const TeacherAlertResult({
    required this.status,
    this.notificationsSent = 0,
    this.notificationIds = const [],
  });

  final TeacherAlertStatus status;
  final int notificationsSent;
  final List<int> notificationIds;

  bool get isSuccess => status == TeacherAlertStatus.sent;
}
