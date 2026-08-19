enum ClassJoinRequestStatus { pending, accepted, rejected }

class ClassJoinRequest {
  const ClassJoinRequest({
    required this.id,
    required this.learnerUserId,
    required this.classId,
    required this.classCode,
    required this.className,
    required this.teacherUserId,
    required this.learnerName,
    required this.status,
    required this.requestedAt,
    this.learnerFirebaseUid,
    this.teacherFirebaseUid,
    this.respondedAt,
    this.remoteId,
  });

  final int id;
  final int learnerUserId;
  final int classId;
  final String classCode;
  final String className;
  final int teacherUserId;
  final String learnerName;
  final String? learnerFirebaseUid;
  final String? teacherFirebaseUid;
  final ClassJoinRequestStatus status;
  final DateTime requestedAt;
  final DateTime? respondedAt;
  final String? remoteId;

  bool get isPending => status == ClassJoinRequestStatus.pending;

  ClassJoinRequest copyWith({
    ClassJoinRequestStatus? status,
    DateTime? respondedAt,
  }) {
    return ClassJoinRequest(
      id: id,
      learnerUserId: learnerUserId,
      classId: classId,
      classCode: classCode,
      className: className,
      teacherUserId: teacherUserId,
      learnerName: learnerName,
      learnerFirebaseUid: learnerFirebaseUid,
      teacherFirebaseUid: teacherFirebaseUid,
      status: status ?? this.status,
      requestedAt: requestedAt,
      respondedAt: respondedAt ?? this.respondedAt,
      remoteId: remoteId,
    );
  }

  static ClassJoinRequestStatus statusFromString(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'accepted':
        return ClassJoinRequestStatus.accepted;
      case 'rejected':
        return ClassJoinRequestStatus.rejected;
      default:
        return ClassJoinRequestStatus.pending;
    }
  }

  static String statusToString(ClassJoinRequestStatus status) {
    switch (status) {
      case ClassJoinRequestStatus.accepted:
        return 'accepted';
      case ClassJoinRequestStatus.rejected:
        return 'rejected';
      case ClassJoinRequestStatus.pending:
        return 'pending';
    }
  }
}
