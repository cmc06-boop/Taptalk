import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/parent_notification.dart';
import '../data/models/teacher_alert_result.dart';
import '../data/models/teacher_class_student.dart';
import '../data/repositories/app_repository.dart';
import 'cloud_notification_backend.dart';

/// Coordinates local SQLite notifications with an optional cloud backend.
class NotificationSyncService {
  NotificationSyncService({
    required this._repository,
    CloudNotificationBackend? cloudBackend,
  })  : _cloud = cloudBackend ?? UnconfiguredCloudNotificationBackend();

  final AppRepository _repository;
  CloudNotificationBackend _cloud;
  StreamSubscription<List<RemoteParentNotification>>? _parentSubscription;
  void Function()? _onParentNotificationsChanged;

  bool get isCloudAvailable => _cloud.isAvailable;

  void attachCloudBackend(CloudNotificationBackend backend) {
    _cloud = backend;
  }

  Future<void> initialize() async {
    await _cloud.initialize();
  }

  Future<TeacherAlertResult> sendTeacherAlert({
    required int teacherUserId,
    required String teacherName,
    required int learnerUserId,
    required String learnerName,
    required int classId,
    required String className,
    required ParentAlertType alertType,
    required String title,
    required String body,
  }) async {
    final result = await _repository.sendTeacherAlertToParents(
      teacherUserId: teacherUserId,
      teacherName: teacherName,
      learnerUserId: learnerUserId,
      learnerName: learnerName,
      classId: classId,
      className: className,
      alertType: alertType,
      title: title,
      body: body,
    );

    if (!result.isSuccess || !_cloud.isAvailable) {
      if (result.status != TeacherAlertStatus.noLinkedParents) {
        return result;
      }
      final learnerFirebaseUid =
          await _repository.getFirebaseUidForUser(learnerUserId);
      if (learnerFirebaseUid == null || learnerFirebaseUid.isEmpty) {
        return result;
      }
      final parentUids =
          await _cloud.getLinkedParentFirebaseUids(learnerFirebaseUid);
      if (parentUids.isEmpty) return result;
      final createdAt = DateTime.now();
      for (final parentUid in parentUids) {
        try {
          await _cloud.publishTeacherAlert(
            TeacherAlertCloudEvent(
              localNotificationId: -1,
              parentUserId: -1,
              parentFirebaseUid: parentUid,
              learnerUserId: learnerUserId,
              childName: learnerName,
              teacherUserId: teacherUserId,
              teacherName: teacherName,
              classId: classId,
              className: className,
              alertType: alertType.name,
              title: title,
              body: body,
              createdAt: createdAt,
            ),
          );
        } catch (e, st) {
          debugPrint('Cloud-only alert publish failed: $e\n$st');
        }
      }
      return TeacherAlertResult(
        status: TeacherAlertStatus.sent,
        notificationsSent: parentUids.length,
      );
    }

    final createdAt = DateTime.now();
    for (final notificationId in result.notificationIds) {
      final parentId =
          await _repository.parentUserIdForNotification(notificationId);
      if (parentId == null) continue;
      final parentFirebaseUid =
          await _repository.getFirebaseUidForUser(parentId);
      if (parentFirebaseUid == null || parentFirebaseUid.isEmpty) continue;
      try {
        await _cloud.publishTeacherAlert(
          TeacherAlertCloudEvent(
            localNotificationId: notificationId,
            parentUserId: parentId,
            parentFirebaseUid: parentFirebaseUid,
            learnerUserId: learnerUserId,
            childName: learnerName,
            teacherUserId: teacherUserId,
            teacherName: teacherName,
            classId: classId,
            className: className,
            alertType: alertType.name,
            title: title,
            body: body,
            createdAt: createdAt,
          ),
        );
      } catch (e, st) {
        debugPrint('Cloud alert publish failed: $e\n$st');
      }
    }

    return result;
  }

  Future<void> syncParentChildLink({
    required int parentUserId,
    required int learnerUserId,
    required String parentFirebaseUid,
    required String learnerFirebaseUid,
    String? learnerName,
    String? learnerProfileCode,
  }) async {
    if (!_cloud.isAvailable) return;
    await _cloud.upsertParentChildLink(
      parentUserId: parentUserId,
      learnerUserId: learnerUserId,
      parentFirebaseUid: parentFirebaseUid,
      learnerFirebaseUid: learnerFirebaseUid,
      learnerName: learnerName,
      learnerProfileCode: learnerProfileCode,
    );
  }

  Future<void> unsyncParentChildLink({
    required String parentFirebaseUid,
    required String learnerFirebaseUid,
  }) async {
    if (!_cloud.isAvailable) return;
    await _cloud.removeParentChildLink(
      parentFirebaseUid: parentFirebaseUid,
      learnerFirebaseUid: learnerFirebaseUid,
    );
  }

  Future<void> syncClassEnrollment({
    required int classId,
    required String classCode,
    required String className,
    required String teacherFirebaseUid,
    required int learnerUserId,
    required String learnerName,
    required String learnerFirebaseUid,
  }) async {
    if (!_cloud.isAvailable) return;
    await _cloud.upsertClassEnrollment(
      ClassEnrollmentCloudEvent(
        classId: classId,
        classCode: classCode,
        className: className,
        teacherFirebaseUid: teacherFirebaseUid,
        learnerUserId: learnerUserId,
        learnerName: learnerName,
        learnerFirebaseUid: learnerFirebaseUid,
        enrolledAt: DateTime.now(),
      ),
    );
  }

  Future<void> unsyncClassEnrollment({
    required String classCode,
    required String learnerFirebaseUid,
  }) async {
    if (!_cloud.isAvailable) return;
    await _cloud.removeClassEnrollment(
      classCode: classCode,
      learnerFirebaseUid: learnerFirebaseUid,
    );
  }

  Future<List<TeacherClassStudent>> getTeacherClassStudentsFromCloud(
    String teacherFirebaseUid,
  ) async {
    if (!_cloud.isAvailable || teacherFirebaseUid.trim().isEmpty) return const [];
    final enrollments =
        await _cloud.getClassEnrollmentsForTeacher(teacherFirebaseUid);
    final students = enrollments
        .where((e) => e.classId > 0 && e.learnerUserId > 0)
        .map(
          (e) => TeacherClassStudent(
            learnerId: e.learnerUserId,
            fullName: e.learnerName,
            classId: e.classId,
            className: e.className,
            classCode: e.classCode,
            enrolledAt: e.enrolledAt,
          ),
        )
        .toList();
    students.sort((a, b) {
      final classSort = a.className.compareTo(b.className);
      if (classSort != 0) return classSort;
      return a.fullName.compareTo(b.fullName);
    });
    return students;
  }

  Future<void> syncTeacherClass({
    required String classCode,
    required String className,
    required String teacherFirebaseUid,
    required int teacherUserId,
    required DateTime createdAt,
  }) async {
    if (!_cloud.isAvailable || teacherFirebaseUid.trim().isEmpty) return;
    await _cloud.upsertTeacherClass(
      TeacherClassCloudEvent(
        classCode: classCode,
        className: className,
        teacherFirebaseUid: teacherFirebaseUid,
        teacherUserId: teacherUserId,
        createdAt: createdAt,
      ),
    );
  }

  Future<void> removeTeacherClass({required String classCode}) async {
    if (!_cloud.isAvailable || classCode.trim().isEmpty) return;
    await _cloud.removeTeacherClass(classCode: classCode);
  }

  Future<List<RemoteTeacherClass>> getTeacherClassesFromCloud(
    String teacherFirebaseUid,
  ) async {
    if (!_cloud.isAvailable || teacherFirebaseUid.trim().isEmpty) return const [];
    return _cloud.getTeacherClassesForTeacher(teacherFirebaseUid);
  }

  Future<List<RemoteClassEnrollment>> getClassEnrollmentsFromCloud(
    String teacherFirebaseUid,
  ) async {
    if (!_cloud.isAvailable || teacherFirebaseUid.trim().isEmpty) return const [];
    return _cloud.getClassEnrollmentsForTeacher(teacherFirebaseUid);
  }

  Future<List<RemoteClassEnrollment>> getClassEnrollmentsForLearnerFromCloud(
    String learnerFirebaseUid,
  ) async {
    if (!_cloud.isAvailable || learnerFirebaseUid.trim().isEmpty) return const [];
    return _cloud.getClassEnrollmentsForLearner(learnerFirebaseUid);
  }

  Future<void> pushLearnerActivity(LearnerActivityCloudEvent event) async {
    if (!_cloud.isAvailable) return;
    try {
      await _cloud.appendLearnerActivity(event);
    } catch (e, st) {
      debugPrint('Push learner activity failed: $e\n$st');
    }
  }

  Future<List<RemoteLearnerActivity>> getLearnerActivitiesFromCloud({
    required String learnerFirebaseUid,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    if (!_cloud.isAvailable || learnerFirebaseUid.trim().isEmpty) return const [];
    try {
      return await _cloud.getLearnerActivities(
        learnerFirebaseUid: learnerFirebaseUid,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
    } catch (e, st) {
      debugPrint('getLearnerActivitiesFromCloud failed: $e\n$st');
      return const [];
    }
  }

  Future<RemoteTeacherClass?> getTeacherClassByCodeFromCloud(
    String classCode,
  ) async {
    if (!_cloud.isAvailable || classCode.trim().isEmpty) return null;
    return _cloud.getTeacherClassByCode(classCode);
  }

  Future<void> syncClassContent(RemoteClassContent content) async {
    if (!_cloud.isAvailable || content.classCode.trim().isEmpty) return;
    try {
      await _cloud.upsertClassContent(content);
    } catch (e, st) {
      debugPrint('syncClassContent failed: $e\n$st');
    }
  }

  Future<RemoteClassContent?> getClassContentFromCloud(String classCode) async {
    if (!_cloud.isAvailable || classCode.trim().isEmpty) return null;
    try {
      return await _cloud.getClassContentByCode(classCode);
    } catch (e, st) {
      debugPrint('getClassContentFromCloud failed: $e\n$st');
      return null;
    }
  }

  Future<RemoteLearnerProfile?> findLearnerProfileByCodeFromCloud(
    String profileCode,
  ) async {
    if (!_cloud.isAvailable || profileCode.trim().isEmpty) return null;
    return _cloud.findLearnerByProfileCode(profileCode);
  }

  Future<List<RemoteParentChildLink>> getParentChildLinksFromCloud(
    String parentFirebaseUid,
  ) async {
    if (!_cloud.isAvailable || parentFirebaseUid.trim().isEmpty) return const [];
    return _cloud.getParentChildLinksForParent(parentFirebaseUid);
  }

  Future<void> syncUserProfile(RemoteUserProfile profile) async {
    if (!_cloud.isAvailable) return;
    await _cloud.upsertUserProfile(profile);
  }

  Future<RemoteUserProfile?> getUserProfileFromCloud(String firebaseUid) async {
    if (!_cloud.isAvailable || firebaseUid.trim().isEmpty) return null;
    return _cloud.getUserProfile(firebaseUid);
  }

  Future<void> syncLearnerEmergencyContacts({
    required int learnerUserId,
    required String learnerName,
    required String learnerFirebaseUid,
    required List<String> contacts,
    String? profileCode,
  }) async {
    if (!_cloud.isAvailable) return;
    await _cloud.upsertLearnerEmergencyContacts(
      learnerUserId: learnerUserId,
      learnerName: learnerName,
      learnerFirebaseUid: learnerFirebaseUid,
      contacts: contacts,
      profileCode: profileCode,
    );
  }

  Future<void> syncLearnerCategories({
    required String learnerFirebaseUid,
    required List<RemoteLearnerCategory> categories,
  }) async {
    if (!_cloud.isAvailable || learnerFirebaseUid.trim().isEmpty) return;
    try {
      await _cloud.upsertLearnerCategories(
        learnerFirebaseUid: learnerFirebaseUid,
        categories: categories,
      );
    } catch (e, st) {
      debugPrint('syncLearnerCategories failed: $e\n$st');
    }
  }

  Future<List<RemoteLearnerCategory>> getLearnerCategoriesFromCloud(
    String learnerFirebaseUid,
  ) async {
    if (!_cloud.isAvailable || learnerFirebaseUid.trim().isEmpty) return const [];
    try {
      return await _cloud.getLearnerCategories(learnerFirebaseUid);
    } catch (e, st) {
      debugPrint('getLearnerCategoriesFromCloud failed: $e\n$st');
      return const [];
    }
  }

  /// Local SQLite first; falls back to Firestore when the teacher device has no
  /// copy of the learner's emergency contacts (typical cross-device setup).
  Future<List<String>> resolveEmergencyContacts({
    required int learnerUserId,
    required List<String> localContacts,
    String? learnerFirebaseUid,
  }) async {
    if (localContacts.isNotEmpty) return localContacts;
    final uid = learnerFirebaseUid?.trim();
    if (!_cloud.isAvailable || uid == null || uid.isEmpty) {
      return localContacts;
    }
    try {
      final cloudContacts = await _cloud.getLearnerEmergencyContacts(uid);
      if (cloudContacts.isEmpty) return localContacts;
      await _repository.updateEmergencyContacts(learnerUserId, cloudContacts);
      return cloudContacts;
    } catch (e, st) {
      debugPrint('Cloud emergency contact fetch failed: $e\n$st');
      return localContacts;
    }
  }

  Future<void> startParentSync({
    required int parentUserId,
    required String parentFirebaseUid,
    required void Function() onChanged,
  }) async {
    await stopParentSync();
    _onParentNotificationsChanged = onChanged;

    if (!_cloud.isAvailable || parentFirebaseUid.trim().isEmpty) return;

    _parentSubscription = _cloud
        .watchParentNotifications(
          parentUserId: parentUserId,
          parentFirebaseUid: parentFirebaseUid,
        )
        .listen(
      (remoteItems) async {
        await _repository.upsertRemoteParentNotifications(
          parentUserId: parentUserId,
          items: remoteItems,
        );
        _onParentNotificationsChanged?.call();
      },
      onError: (Object e, StackTrace st) {
        debugPrint('Parent notification sync error: $e\n$st');
      },
    );
  }

  Future<void> markRemoteNotificationRead(String remoteId) async {
    if (!_cloud.isAvailable || remoteId.trim().isEmpty) return;
    await _cloud.markParentNotificationRead(remoteId.trim());
  }

  Future<void> markAllRemoteNotificationsRead(List<String> remoteIds) async {
    if (!_cloud.isAvailable || remoteIds.isEmpty) return;
    for (final id in remoteIds) {
      await _cloud.markParentNotificationRead(id);
    }
  }

  Future<void> stopParentSync() async {
    await _parentSubscription?.cancel();
    _parentSubscription = null;
    _onParentNotificationsChanged = null;
  }

  Future<void> dispose() async {
    await stopParentSync();
    await _cloud.dispose();
  }
}
