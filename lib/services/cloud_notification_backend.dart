/// Payload pushed to a cloud backend when a teacher alerts linked parents.
class TeacherAlertCloudEvent {
  const TeacherAlertCloudEvent({
    required this.localNotificationId,
    required this.parentUserId,
    required this.parentFirebaseUid,
    required this.learnerUserId,
    required this.childName,
    required this.teacherUserId,
    required this.teacherFirebaseUid,
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
  final String teacherFirebaseUid;
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
        'teacherFirebaseUid': teacherFirebaseUid,
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
    this.teacherName,
  });

  final int classId;
  final String classCode;
  final String className;
  final String teacherFirebaseUid;
  final int learnerUserId;
  final String learnerName;
  final String learnerFirebaseUid;
  final DateTime enrolledAt;
  final String? teacherName;

  Map<String, Object?> toFirestoreMap() => {
        'classId': classId,
        'classCode': classCode,
        'className': className,
        'teacherFirebaseUid': teacherFirebaseUid,
        'learnerUserId': learnerUserId,
        'learnerName': learnerName,
        'learnerFirebaseUid': learnerFirebaseUid,
        'enrolledAt': enrolledAt.toUtc().toIso8601String(),
        if (teacherName != null && teacherName!.trim().isNotEmpty)
          'teacherName': teacherName!.trim(),
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
    this.teacherName,
  });

  final int classId;
  final String classCode;
  final String className;
  final int learnerUserId;
  final String learnerName;
  final String learnerFirebaseUid;
  final DateTime enrolledAt;
  final String? teacherName;
}

class RemoteTeacherClass {
  const RemoteTeacherClass({
    required this.classCode,
    required this.className,
    required this.teacherFirebaseUid,
    required this.teacherUserId,
    required this.createdAt,
    this.teacherName,
  });

  final String classCode;
  final String className;
  final String teacherFirebaseUid;
  final int teacherUserId;
  final DateTime createdAt;
  final String? teacherName;
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

/// Learner-created phrase synced for cross-device vocabulary growth.
class RemoteLearnerCustomPhrase {
  const RemoteLearnerCustomPhrase({
    required this.phraseText,
    required this.categoryKey,
    required this.createdAt,
    this.imagePath,
  });

  final String phraseText;
  final String categoryKey;
  final DateTime createdAt;
  final String? imagePath;

  Map<String, Object?> toFirestoreMap() => {
        'phraseText': phraseText,
        'categoryKey': categoryKey,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (imagePath != null && imagePath!.trim().isNotEmpty)
          'imagePath': imagePath!.trim(),
      };

  factory RemoteLearnerCustomPhrase.fromMap(Map<String, dynamic> map) {
    final createdRaw = map['createdAt'];
    DateTime createdAt = DateTime.now();
    if (createdRaw is String) {
      createdAt = DateTime.tryParse(createdRaw)?.toLocal() ?? createdAt;
    }
    return RemoteLearnerCustomPhrase(
      phraseText: (map['phraseText'] as String?) ?? '',
      categoryKey: (map['categoryKey'] as String?) ?? '',
      createdAt: createdAt,
      imagePath: map['imagePath'] as String?,
    );
  }
}

class RemoteLearnerFavorite {
  const RemoteLearnerFavorite({
    required this.phraseText,
    required this.categoryKey,
    this.phraseId,
    this.imagePath,
  });

  final String phraseText;
  final String categoryKey;
  final int? phraseId;
  final String? imagePath;

  Map<String, Object?> toFirestoreMap() => {
        'phraseText': phraseText,
        'categoryKey': categoryKey,
        if (phraseId != null) 'phraseId': phraseId,
        if (imagePath != null && imagePath!.trim().isNotEmpty)
          'imagePath': imagePath!.trim(),
      };

  factory RemoteLearnerFavorite.fromMap(Map<String, dynamic> map) {
    return RemoteLearnerFavorite(
      phraseText: (map['phraseText'] as String?) ?? '',
      categoryKey: (map['categoryKey'] as String?) ?? '',
      phraseId: map['phraseId'] as int?,
      imagePath: map['imagePath'] as String?,
    );
  }
}

class RemoteLearnerSpeakHistory {
  const RemoteLearnerSpeakHistory({
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

  Map<String, Object?> toFirestoreMap() => {
        'phraseText': phraseText,
        'categoryKey': categoryKey,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (className != null && className!.trim().isNotEmpty)
          'className': className!.trim(),
        if (lessonTitle != null && lessonTitle!.trim().isNotEmpty)
          'lessonTitle': lessonTitle!.trim(),
      };

  factory RemoteLearnerSpeakHistory.fromMap(Map<String, dynamic> map) {
    final createdRaw = map['createdAt'];
    DateTime createdAt = DateTime.now();
    if (createdRaw is String) {
      createdAt = DateTime.tryParse(createdRaw)?.toLocal() ?? createdAt;
    }
    return RemoteLearnerSpeakHistory(
      phraseText: (map['phraseText'] as String?) ?? '',
      categoryKey: (map['categoryKey'] as String?) ?? '',
      createdAt: createdAt,
      className: map['className'] as String?,
      lessonTitle: map['lessonTitle'] as String?,
    );
  }
}

/// Live snapshot of For Me board data stored on `learner_profiles`.
class RemoteLearnerPersonalBoardSnapshot {
  const RemoteLearnerPersonalBoardSnapshot({
    this.categories = const [],
    this.customPhrases = const [],
    this.favorites = const [],
    this.speakHistory = const [],
  });

  final List<RemoteLearnerCategory> categories;
  final List<RemoteLearnerCustomPhrase> customPhrases;
  final List<RemoteLearnerFavorite> favorites;
  final List<RemoteLearnerSpeakHistory> speakHistory;
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
    this.firstName,
    this.themeKey,
    this.profileCode,
    this.language,
    this.ttsSpeed,
  });

  final String firebaseUid;
  final String email;
  final String fullName;
  final String role;
  final String? firstName;
  final String? themeKey;
  final String? profileCode;
  final String? language;
  final double? ttsSpeed;
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
    this.teacherName,
  });

  final String classCode;
  final String className;
  final String teacherFirebaseUid;
  final int teacherUserId;
  final DateTime createdAt;
  final String? teacherName;

  Map<String, Object?> toFirestoreMap() => {
        'classCode': classCode,
        'className': className,
        'teacherFirebaseUid': teacherFirebaseUid,
        'teacherUserId': teacherUserId,
        'createdAt': createdAt.toUtc().toIso8601String(),
        if (teacherName != null && teacherName!.trim().isNotEmpty)
          'teacherName': teacherName!.trim(),
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

/// Teacher alert pulled from Firestore for cross-device recent alerts.
class RemoteTeacherAlert {
  const RemoteTeacherAlert({
    required this.remoteId,
    required this.teacherUserId,
    required this.parentUserId,
    required this.learnerUserId,
    required this.childName,
    required this.classId,
    required this.className,
    required this.alertType,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  final String remoteId;
  final int teacherUserId;
  final int parentUserId;
  final int learnerUserId;
  final String childName;
  final int classId;
  final String className;
  final String alertType;
  final String title;
  final String body;
  final DateTime createdAt;
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

  Stream<List<RemoteLearnerActivity>> watchLearnerActivities(
    String learnerFirebaseUid,
  );

  Future<void> upsertTeacherClass(TeacherClassCloudEvent event);

  Future<void> removeTeacherClass({required String classCode});

  Future<void> removeClassEnrollmentsForClass({required String classCode});

  Future<List<RemoteTeacherClass>> getTeacherClassesForTeacher(
    String teacherFirebaseUid,
  );

  Future<RemoteTeacherClass?> getTeacherClassByCode(String classCode);

  Future<void> upsertClassContent(RemoteClassContent content);

  Future<RemoteClassContent?> getClassContentByCode(String classCode);

  Stream<RemoteClassContent?> watchClassContentByCode(String classCode);

  Future<RemoteLearnerProfile?> findLearnerByProfileCode(String profileCode);

  Future<List<RemoteParentChildLink>> getParentChildLinksForParent(
    String parentFirebaseUid,
  );

  Future<void> upsertUserProfile(RemoteUserProfile profile);

  Future<RemoteUserProfile?> getUserProfile(String firebaseUid);

  Stream<RemoteUserProfile> watchUserProfile(String firebaseUid);

  /// Updates learner name on all parent-child links and class enrollments.
  Future<void> updateLearnerReferencesOnCloud({
    required String learnerFirebaseUid,
    required String learnerName,
    String? learnerProfileCode,
  });

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

  Future<void> upsertLearnerCustomPhrases({
    required String learnerFirebaseUid,
    required List<RemoteLearnerCustomPhrase> phrases,
  });

  Future<List<RemoteLearnerCustomPhrase>> getLearnerCustomPhrases(
    String learnerFirebaseUid,
  );

  Future<void> upsertLearnerFavorites({
    required String learnerFirebaseUid,
    required List<RemoteLearnerFavorite> favorites,
  });

  Future<List<RemoteLearnerFavorite>> getLearnerFavorites(
    String learnerFirebaseUid,
  );

  Future<void> upsertLearnerSpeakHistory({
    required String learnerFirebaseUid,
    required List<RemoteLearnerSpeakHistory> history,
  });

  Future<List<RemoteLearnerSpeakHistory>> getLearnerSpeakHistory(
    String learnerFirebaseUid,
  );

  Stream<List<RemoteParentNotification>> watchParentNotifications({
    required int parentUserId,
    required String parentFirebaseUid,
  });

  Future<List<RemoteTeacherAlert>> getTeacherAlerts({
    required int teacherUserId,
    required String teacherFirebaseUid,
  });

  Stream<List<RemoteTeacherAlert>> watchTeacherAlerts({
    required int teacherUserId,
    required String teacherFirebaseUid,
  });

  Stream<List<RemoteClassEnrollment>> watchClassEnrollmentsForLearner(
    String learnerFirebaseUid,
  );

  Stream<List<RemoteClassEnrollment>> watchClassEnrollmentsForTeacher(
    String teacherFirebaseUid,
  );

  Stream<List<RemoteParentChildLink>> watchParentChildLinks(
    String parentFirebaseUid,
  );

  Stream<List<RemoteTeacherClass>> watchTeacherClassesForTeacher(
    String teacherFirebaseUid,
  );

  Stream<RemoteLearnerPersonalBoardSnapshot> watchLearnerPersonalBoard(
    String learnerFirebaseUid,
  );

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
  Stream<List<RemoteLearnerActivity>> watchLearnerActivities(
    String learnerFirebaseUid,
  ) =>
      const Stream.empty();

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
  Stream<RemoteClassContent?> watchClassContentByCode(String classCode) =>
      const Stream.empty();

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
  Stream<RemoteUserProfile> watchUserProfile(String firebaseUid) =>
      const Stream.empty();

  @override
  Future<void> updateLearnerReferencesOnCloud({
    required String learnerFirebaseUid,
    required String learnerName,
    String? learnerProfileCode,
  }) async {}

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
  Future<void> upsertLearnerCustomPhrases({
    required String learnerFirebaseUid,
    required List<RemoteLearnerCustomPhrase> phrases,
  }) async {}

  @override
  Future<List<RemoteLearnerCustomPhrase>> getLearnerCustomPhrases(
    String learnerFirebaseUid,
  ) async =>
      const [];

  @override
  Future<void> upsertLearnerFavorites({
    required String learnerFirebaseUid,
    required List<RemoteLearnerFavorite> favorites,
  }) async {}

  @override
  Future<List<RemoteLearnerFavorite>> getLearnerFavorites(
    String learnerFirebaseUid,
  ) async =>
      const [];

  @override
  Future<void> upsertLearnerSpeakHistory({
    required String learnerFirebaseUid,
    required List<RemoteLearnerSpeakHistory> history,
  }) async {}

  @override
  Future<List<RemoteLearnerSpeakHistory>> getLearnerSpeakHistory(
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
  Future<List<RemoteTeacherAlert>> getTeacherAlerts({
    required int teacherUserId,
    required String teacherFirebaseUid,
  }) async =>
      const [];

  @override
  Stream<List<RemoteTeacherAlert>> watchTeacherAlerts({
    required int teacherUserId,
    required String teacherFirebaseUid,
  }) =>
      const Stream.empty();

  @override
  Stream<List<RemoteClassEnrollment>> watchClassEnrollmentsForLearner(
    String learnerFirebaseUid,
  ) =>
      const Stream.empty();

  @override
  Stream<List<RemoteClassEnrollment>> watchClassEnrollmentsForTeacher(
    String teacherFirebaseUid,
  ) =>
      const Stream.empty();

  @override
  Stream<List<RemoteParentChildLink>> watchParentChildLinks(
    String parentFirebaseUid,
  ) =>
      const Stream.empty();

  @override
  Stream<List<RemoteTeacherClass>> watchTeacherClassesForTeacher(
    String teacherFirebaseUid,
  ) =>
      const Stream.empty();

  @override
  Stream<RemoteLearnerPersonalBoardSnapshot> watchLearnerPersonalBoard(
    String learnerFirebaseUid,
  ) =>
      const Stream.empty();

  @override
  Future<void> markParentNotificationRead(String remoteId) async {}
}
