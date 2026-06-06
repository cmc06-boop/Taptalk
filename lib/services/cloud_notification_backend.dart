/// Payload pushed to a cloud backend when a teacher alerts linked parents.
class TeacherAlertCloudEvent {
  const TeacherAlertCloudEvent({
    required this.localNotificationId,
    required this.parentUserId,
    required this.parentFirebaseUid,
    required this.learnerUserId,
    required this.childName,
    required this.teacherUserId,
    required this.teacherName,
    required this.classId,
    required this.className,
    required this.alertType,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  final int localNotificationId;
  final int parentUserId;
  final String parentFirebaseUid;
  final int learnerUserId;
  final String childName;
  final int teacherUserId;
  final String teacherName;
  final int classId;
  final String className;
  final String alertType;
  final String title;
  final String body;
  final DateTime createdAt;

  Map<String, Object?> toFirestoreMap() => {
        'localNotificationId': localNotificationId,
        'parentUserId': parentUserId,
        'learnerUserId': learnerUserId,
        'childName': childName,
        'teacherUserId': teacherUserId,
        'teacherName': teacherName,
        'classId': classId,
        'className': className,
        'title': title,
        'body': body,
        'alertType': alertType,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'isRead': false,
      };
}

class ClassEnrollmentCloudEvent {
  const ClassEnrollmentCloudEvent({
    required this.classId,
    required this.classCode,
    required this.className,
    required this.teacherFirebaseUid,
    required this.learnerUserId,
    required this.learnerName,
    required this.learnerFirebaseUid,
    required this.enrolledAt,
  });

  final int classId;
  final String classCode;
  final String className;
  final String teacherFirebaseUid;
  final int learnerUserId;
  final String learnerName;
  final String learnerFirebaseUid;
  final DateTime enrolledAt;

  Map<String, Object?> toFirestoreMap() => {
        'classId': classId,
        'classCode': classCode,
        'className': className,
        'teacherFirebaseUid': teacherFirebaseUid,
        'learnerUserId': learnerUserId,
        'learnerName': learnerName,
        'learnerFirebaseUid': learnerFirebaseUid,
        'enrolledAt': enrolledAt.toUtc().toIso8601String(),
      };
}

class RemoteClassEnrollment {
  const RemoteClassEnrollment({
    required this.classId,
    required this.classCode,
    required this.className,
    required this.learnerUserId,
    required this.learnerName,
    required this.learnerFirebaseUid,
    required this.enrolledAt,
  });

  final int classId;
  final String classCode;
  final String className;
  final int learnerUserId;
  final String learnerName;
  final String learnerFirebaseUid;
  final DateTime enrolledAt;
}

class RemoteTeacherClass {
  const RemoteTeacherClass({
    required this.classCode,
    required this.className,
    required this.teacherFirebaseUid,
    required this.teacherUserId,
    required this.createdAt,
  });

  final String classCode;
  final String className;
  final String teacherFirebaseUid;
  final int teacherUserId;
  final DateTime createdAt;
}

class RemoteLearnerProfile {
  const RemoteLearnerProfile({
    required this.learnerFirebaseUid,
    required this.learnerName,
    required this.profileCode,
    required this.learnerUserId,
  });

  final String learnerFirebaseUid;
  final String learnerName;
  final String profileCode;
  final int learnerUserId;
}

class RemoteLearnerCategory {
  const RemoteLearnerCategory({
    required this.key,
    required this.name,
    this.iconKey = 'custom',
  });

  final String key;
  final String name;
  final String iconKey;

  Map<String, Object?> toFirestoreMap() => {
        'key': key,
        'name': name,
        'iconKey': iconKey,
      };

  factory RemoteLearnerCategory.fromMap(Map<String, dynamic> map) {
    return RemoteLearnerCategory(
      key: (map['key'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      iconKey: (map['iconKey'] as String?) ?? 'custom',
    );
  }
}

class RemoteParentChildLink {
  const RemoteParentChildLink({
    required this.parentFirebaseUid,
    required this.learnerFirebaseUid,
    required this.parentUserId,
    required this.learnerUserId,
    required this.learnerName,
    required this.learnerProfileCode,
  });

  final String parentFirebaseUid;
  final String learnerFirebaseUid;
  final int parentUserId;
  final int learnerUserId;
  final String learnerName;
  final String learnerProfileCode;
}

class RemoteUserProfile {
  const RemoteUserProfile({
    required this.firebaseUid,
    required this.email,
    required this.fullName,
    required this.role,
    this.themeKey,
    this.profileCode,
  });

  final String firebaseUid;
  final String email;
  final String fullName;
  final String role;
  final String? themeKey;
  final String? profileCode;
}

/// Phrase tap / history event synced for cross-device monitoring.
class LearnerActivityCloudEvent {
  const LearnerActivityCloudEvent({
    required this.learnerFirebaseUid,
    required this.phraseText,
    required this.categoryKey,
    required this.createdAt,
    this.className,
    this.lessonTitle,
  });

  final String learnerFirebaseUid;
  final String phraseText;
  final String categoryKey;
  final DateTime createdAt;
  final String? className;
  final String? lessonTitle;

  Map<String, Object?> toFirestoreMap() => {
        'learnerFirebaseUid': learnerFirebaseUid,
        'phraseText': phraseText,
        'categoryKey': categoryKey,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (className != null && className!.trim().isNotEmpty)
          'className': className!.trim(),
        if (lessonTitle != null && lessonTitle!.trim().isNotEmpty)
          'lessonTitle': lessonTitle!.trim(),
      };
}

class RemoteLearnerActivity {
  const RemoteLearnerActivity({
    required this.phraseText,
    required this.categoryKey,
    required this.createdAt,
    this.className,
    this.lessonTitle,
  });

  final String phraseText;
  final String categoryKey;
  final DateTime createdAt;
  final String? className;
  final String? lessonTitle;
}

class RemoteLessonPhraseContent {
  const RemoteLessonPhraseContent({
    required this.phraseKey,
    required this.text,
    required this.sortOrder,
    this.imagePath,
  });

  final String phraseKey;
  final String text;
  final int sortOrder;
  final String? imagePath;
}

class RemoteClassLessonContent {
  const RemoteClassLessonContent({
    required this.lessonKey,
    required this.title,
    required this.sortOrder,
    required this.createdAt,
    required this.phrases,
  });

  final String lessonKey;
  final String title;
  final int sortOrder;
  final DateTime createdAt;
  final List<RemoteLessonPhraseContent> phrases;
}

class RemoteClassContent {
  const RemoteClassContent({
    required this.classCode,
    required this.className,
    required this.teacherFirebaseUid,
    required this.updatedAt,
    required this.lessons,
  });

  final String classCode;
  final String className;
  final String teacherFirebaseUid;
  final DateTime updatedAt;
  final List<RemoteClassLessonContent> lessons;
}

class TeacherClassCloudEvent {
  const TeacherClassCloudEvent({
    required this.classCode,
    required this.className,
    required this.teacherFirebaseUid,
    required this.teacherUserId,
    required this.createdAt,
  });

  final String classCode;
  final String className;
  final String teacherFirebaseUid;
  final int teacherUserId;
  final DateTime createdAt;

  Map<String, Object?> toFirestoreMap() => {
        'classCode': classCode,
        'className': className,
        'teacherFirebaseUid': teacherFirebaseUid,
        'teacherUserId': teacherUserId,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };
}

/// Remote notification pulled from the cloud into local SQLite.
class RemoteParentNotification {
  const RemoteParentNotification({
    required this.remoteId,
    required this.parentUserId,
    required this.learnerUserId,
    required this.childName,
    required this.title,
    required this.body,
    required this.alertType,
    required this.createdAt,
    required this.isRead,
  });

  final String remoteId;
  final int parentUserId;
  final int? learnerUserId;
  final String childName;
  final String title;
  final String body;
  final String alertType;
  final DateTime createdAt;
  final bool isRead;
}

/// Cloud backend for cross-device in-app notifications.
///
/// Implement with Firebase Firestore once [FirebaseService] is configured.
/// Firestore collection: `parent_notifications`
/// Parent listener query: `where('parentUserId', isEqualTo: <parent local id>)`
abstract class CloudNotificationBackend {
  Future<void> initialize();

  bool get isAvailable;

  Future<void> publishTeacherAlert(TeacherAlertCloudEvent event);

  Future<void> upsertParentChildLink({
    required int parentUserId,
    required int learnerUserId,
    required String parentFirebaseUid,
    required String learnerFirebaseUid,
    String? learnerName,
    String? learnerProfileCode,
  });

  Future<void> removeParentChildLink({
    required String parentFirebaseUid,
    required String learnerFirebaseUid,
  });

  Future<List<String>> getLinkedParentFirebaseUids(String learnerFirebaseUid);

  Future<void> upsertClassEnrollment(ClassEnrollmentCloudEvent event);

  Future<void> removeClassEnrollment({
    required String classCode,
    required String learnerFirebaseUid,
  });

  Future<List<RemoteClassEnrollment>> getClassEnrollmentsForTeacher(
    String teacherFirebaseUid,
  );

  Future<List<RemoteClassEnrollment>> getClassEnrollmentsForLearner(
    String learnerFirebaseUid,
  );

  Future<void> appendLearnerActivity(LearnerActivityCloudEvent event);

  Future<List<RemoteLearnerActivity>> getLearnerActivities({
    required String learnerFirebaseUid,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });

  Future<void> upsertTeacherClass(TeacherClassCloudEvent event);

  Future<void> removeTeacherClass({required String classCode});

  Future<void> removeClassEnrollmentsForClass({required String classCode});

  Future<List<RemoteTeacherClass>> getTeacherClassesForTeacher(
    String teacherFirebaseUid,
  );

  Future<RemoteTeacherClass?> getTeacherClassByCode(String classCode);

  Future<void> upsertClassContent(RemoteClassContent content);

  Future<RemoteClassContent?> getClassContentByCode(String classCode);

  Future<RemoteLearnerProfile?> findLearnerByProfileCode(String profileCode);

  Future<List<RemoteParentChildLink>> getParentChildLinksForParent(
    String parentFirebaseUid,
  );

  Future<void> upsertUserProfile(RemoteUserProfile profile);

  Future<RemoteUserProfile?> getUserProfile(String firebaseUid);

  Future<void> upsertLearnerEmergencyContacts({
    required int learnerUserId,
    required String learnerName,
    required String learnerFirebaseUid,
    required List<String> contacts,
    String? profileCode,
  });

  Future<List<String>> getLearnerEmergencyContacts(String learnerFirebaseUid);

  Future<void> upsertLearnerCategories({
    required String learnerFirebaseUid,
    required List<RemoteLearnerCategory> categories,
  });

  Future<List<RemoteLearnerCategory>> getLearnerCategories(
    String learnerFirebaseUid,
  );

  Stream<List<RemoteParentNotification>> watchParentNotifications({
    required int parentUserId,
    required String parentFirebaseUid,
  });

  Future<void> markParentNotificationRead(String remoteId);

  Future<void> dispose();
}

/// Default stub until Firebase is wired. Local alerts still work on-device.
class UnconfiguredCloudNotificationBackend implements CloudNotificationBackend {
  @override
  bool get isAvailable => false;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> publishTeacherAlert(TeacherAlertCloudEvent event) async {}

  @override
  Future<void> upsertParentChildLink({
    required int parentUserId,
    required int learnerUserId,
    required String parentFirebaseUid,
    required String learnerFirebaseUid,
    String? learnerName,
    String? learnerProfileCode,
  }) async {}

  @override
  Future<void> removeParentChildLink({
    required String parentFirebaseUid,
    required String learnerFirebaseUid,
  }) async {}

  @override
  Future<List<String>> getLinkedParentFirebaseUids(
    String learnerFirebaseUid,
  ) async =>
      const [];

  @override
  Future<void> upsertClassEnrollment(ClassEnrollmentCloudEvent event) async {}

  @override
  Future<void> removeClassEnrollment({
    required String classCode,
    required String learnerFirebaseUid,
  }) async {}

  @override
  Future<List<RemoteClassEnrollment>> getClassEnrollmentsForTeacher(
    String teacherFirebaseUid,
  ) async =>
      const [];

  @override
  Future<List<RemoteClassEnrollment>> getClassEnrollmentsForLearner(
    String learnerFirebaseUid,
  ) async =>
      const [];

  @override
  Future<void> appendLearnerActivity(LearnerActivityCloudEvent event) async {}

  @override
  Future<List<RemoteLearnerActivity>> getLearnerActivities({
    required String learnerFirebaseUid,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async =>
      const [];

  @override
  Future<void> upsertTeacherClass(TeacherClassCloudEvent event) async {}

  @override
  Future<void> removeTeacherClass({required String classCode}) async {}

  @override
  Future<void> removeClassEnrollmentsForClass({required String classCode}) async {}

  @override
  Future<List<RemoteTeacherClass>> getTeacherClassesForTeacher(
    String teacherFirebaseUid,
  ) async =>
      const [];

  @override
  Future<RemoteTeacherClass?> getTeacherClassByCode(String classCode) async =>
      null;

  @override
  Future<void> upsertClassContent(RemoteClassContent content) async {}

  @override
  Future<RemoteClassContent?> getClassContentByCode(String classCode) async =>
      null;

  @override
  Future<RemoteLearnerProfile?> findLearnerByProfileCode(
    String profileCode,
  ) async =>
      null;

  @override
  Future<List<RemoteParentChildLink>> getParentChildLinksForParent(
    String parentFirebaseUid,
  ) async =>
      const [];

  @override
  Future<void> upsertUserProfile(RemoteUserProfile profile) async {}

  @override
  Future<RemoteUserProfile?> getUserProfile(String firebaseUid) async => null;

  @override
  Future<void> upsertLearnerEmergencyContacts({
    required int learnerUserId,
    required String learnerName,
    required String learnerFirebaseUid,
    required List<String> contacts,
    String? profileCode,
  }) async {}

  @override
  Future<List<String>> getLearnerEmergencyContacts(
    String learnerFirebaseUid,
  ) async =>
      const [];

  @override
  Future<void> upsertLearnerCategories({
    required String learnerFirebaseUid,
    required List<RemoteLearnerCategory> categories,
  }) async {}

  @override
  Future<List<RemoteLearnerCategory>> getLearnerCategories(
    String learnerFirebaseUid,
  ) async =>
      const [];

  @override
  Stream<List<RemoteParentNotification>> watchParentNotifications({
    required int parentUserId,
    required String parentFirebaseUid,
  }) =>
      const Stream.empty();

  @override
  Future<void> markParentNotificationRead(String remoteId) async {}
}
