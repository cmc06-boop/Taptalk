enum ParentAlertType {
  needsAttention,
  distress,
  schoolNeeded,
  teacherAlert,
}

class ParentNotification {
  const ParentNotification({
    required this.id,
    required this.parentUserId,
    this.learnerUserId,
    required this.childName,
    required this.alertType,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
  });

  final int id;
  final int parentUserId;
  final int? learnerUserId;
  final String childName;
  final ParentAlertType alertType;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  ParentNotification copyWith({bool? isRead}) {
    return ParentNotification(
      id: id,
      parentUserId: parentUserId,
      learnerUserId: learnerUserId,
      childName: childName,
      alertType: alertType,
      title: title,
      body: body,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  static ParentAlertType alertTypeFromKey(String key) {
    return ParentAlertType.values.firstWhere(
      (t) => t.name == key,
      orElse: () => ParentAlertType.needsAttention,
    );
  }

  String get alertTypeKey => alertType.name;
}
