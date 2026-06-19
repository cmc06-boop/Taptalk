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
  StreamSubscription<List<RemoteClassEnrollment>>? _learnerEnrollmentSubscription;
  StreamSubscription<List<RemoteClassEnrollment>>? _teacherEnrollmentSubscription;
  StreamSubscription<List<RemoteParentChildLink>>? _parentChildLinkSubscription;
  StreamSubscription<List<RemoteTeacherClass>>? _teacherClassSubscription;
  StreamSubscription<List<RemoteTeacherAlert>>? _teacherAlertSubscription;
  StreamSubscription<RemoteLearnerPersonalBoardSnapshot>? _personalBoardSubscription;
  StreamSubscription<RemoteUserProfile>? _userProfileSubscription;
  final Map<int, StreamSubscription<List<RemoteLearnerActivity>>>
      _monitoredLearnerActivitySubscriptions = {};
  final Map<int, StreamSubscription<RemoteClassContent?>>
      _classContentSubscriptions = {};
  final Map<int, int> _lastAppliedClassContentFingerprint = {};
  void Function()? _onParentNotificationsChanged;
  void Function()? _onLearnerEnrollmentsChanged;
  void Function(List<RemoteClassEnrollment>)? _onTeacherEnrollmentsChanged;
  void Function()? _onParentChildLinksChanged;
  void Function(List<RemoteTeacherClass>)? _onTeacherClassesChanged;
  void Function()? _onTeacherAlertsChanged;
  void Function(RemoteLearnerPersonalBoardSnapshot)? _onPersonalBoardChanged;
  void Function(RemoteUserProfile)? _onUserProfileChanged;

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
    var parentIds = await _repository.getLinkedParentIds(learnerUserId);
    if (parentIds.isEmpty) {
      parentIds = await _resolveLinkedParentIdsFromCloud(learnerUserId);
    }

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
      parentUserIds: parentIds,
    );

    if (!_cloud.isAvailable) {
      return result;
    }

    final teacherFirebaseUid =
        await _repository.getFirebaseUidForUser(teacherUserId);
    if (teacherFirebaseUid == null || teacherFirebaseUid.isEmpty) {
      return result;
    }

    final createdAt = DateTime.now();
    var cloudPublished = 0;

    for (final notificationId in result.notificationIds) {
      final parentId =
          await _repository.parentUserIdForNotification(notificationId);
      if (parentId == null || parentId <= 0) continue;
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
            teacherFirebaseUid: teacherFirebaseUid,
            teacherName: teacherName,
            classId: classId,
            className: className,
            alertType: alertType.name,
            title: title,
            body: body,
            createdAt: createdAt,
          ),
        );
        cloudPublished++;
      } catch (e, st) {
        debugPrint('Cloud alert publish failed: $e\n$st');
      }
    }

    if (cloudPublished == 0) {
      final learnerFirebaseUid =
          await _repository.getFirebaseUidForUser(learnerUserId);
      if (learnerFirebaseUid != null && learnerFirebaseUid.isNotEmpty) {
        final parentUids =
            await _cloud.getLinkedParentFirebaseUids(learnerFirebaseUid);
        final localNotificationId =
            result.notificationIds.isNotEmpty ? result.notificationIds.first : -1;
        for (final parentUid in parentUids) {
          try {
            await _cloud.publishTeacherAlert(
              TeacherAlertCloudEvent(
                localNotificationId: localNotificationId,
                parentUserId: -1,
                parentFirebaseUid: parentUid,
                learnerUserId: learnerUserId,
                childName: learnerName,
                teacherUserId: teacherUserId,
                teacherFirebaseUid: teacherFirebaseUid,
                teacherName: teacherName,
                classId: classId,
                className: className,
                alertType: alertType.name,
                title: title,
                body: body,
                createdAt: createdAt,
              ),
            );
            cloudPublished++;
          } catch (e, st) {
            debugPrint('Cloud-only alert publish failed: $e\n$st');
          }
        }
      }
    }

    if (result.status == TeacherAlertStatus.noLinkedParents &&
        cloudPublished > 0) {
      return TeacherAlertResult(
        status: TeacherAlertStatus.sent,
        notificationsSent: cloudPublished,
        notificationIds: result.notificationIds,
      );
    }

    return result;
  }

  Future<List<int>> _resolveLinkedParentIdsFromCloud(int learnerUserId) async {
    if (!_cloud.isAvailable) return const [];
    final learnerFirebaseUid =
        await _repository.getFirebaseUidForUser(learnerUserId);
    if (learnerFirebaseUid == null || learnerFirebaseUid.isEmpty) {
      return const [];
    }
    final parentUids =
        await _cloud.getLinkedParentFirebaseUids(learnerFirebaseUid);
    if (parentUids.isEmpty) return const [];

    final parentIds = <int>[];
    for (final parentUid in parentUids) {
      final existing = await _repository.findUserByFirebaseUid(parentUid);
      if (existing != null) {
        parentIds.add(existing.id);
        continue;
      }
      final id = await _repository.ensureUserStubFromFirebase(
        firebaseUid: parentUid,
        role: 'parent',
        displayName: 'Parent',
      );
      parentIds.add(id);
    }
    return parentIds;
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
    String? teacherName,
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
        teacherName: teacherName,
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
    String? teacherName,
  }) async {
    if (!_cloud.isAvailable || teacherFirebaseUid.trim().isEmpty) return;
    await _cloud.upsertTeacherClass(
      TeacherClassCloudEvent(
        classCode: classCode,
        className: className,
        teacherFirebaseUid: teacherFirebaseUid,
        teacherUserId: teacherUserId,
        createdAt: createdAt,
        teacherName: teacherName,
      ),
    );
  }

  Future<void> removeTeacherClass({required String classCode}) async {
    if (!_cloud.isAvailable || classCode.trim().isEmpty) return;
    await _cloud.removeTeacherClass(classCode: classCode);
  }

  Future<void> removeClassEnrollmentsForClass({required String classCode}) async {
    if (!_cloud.isAvailable || classCode.trim().isEmpty) return;
    await _cloud.removeClassEnrollmentsForClass(classCode: classCode);
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

  Future<bool> pushLearnerActivity(LearnerActivityCloudEvent event) async {
    if (!_cloud.isAvailable) return false;
    try {
      await _cloud.appendLearnerActivity(event);
      return true;
    } catch (e, st) {
      debugPrint('Push learner activity failed: $e\n$st');
      return false;
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

  Future<void> startMonitoredLearnerActivitySync({
    required int learnerUserId,
    required String learnerFirebaseUid,
    required Future<void> Function(List<RemoteLearnerActivity> activities)
        onChanged,
  }) async {
    await stopMonitoredLearnerActivitySync(learnerUserId);
    await _cloud.initialize();
    if (!_cloud.isAvailable || learnerFirebaseUid.trim().isEmpty) return;

    _monitoredLearnerActivitySubscriptions[learnerUserId] = _cloud
        .watchLearnerActivities(learnerFirebaseUid)
        .listen(
      (activities) async {
        if (activities.isEmpty) return;
        try {
          await onChanged(activities);
        } catch (e, st) {
          debugPrint('Monitored learner activity handler failed: $e\n$st');
        }
      },
      onError: (Object e, StackTrace st) {
        debugPrint('Monitored learner activity sync error: $e\n$st');
      },
    );
  }

  Future<void> stopMonitoredLearnerActivitySync(int learnerUserId) async {
    await _monitoredLearnerActivitySubscriptions.remove(learnerUserId)?.cancel();
  }

  Future<void> stopAllMonitoredLearnerActivitySync() async {
    for (final sub in _monitoredLearnerActivitySubscriptions.values) {
      await sub.cancel();
    }
    _monitoredLearnerActivitySubscriptions.clear();
  }

  Future<RemoteTeacherClass?> getTeacherClassByCodeFromCloud(
    String classCode,
  ) async {
    if (!_cloud.isAvailable || classCode.trim().isEmpty) return null;
    return _cloud.getTeacherClassByCode(classCode);
  }

  Future<bool> syncClassContent(RemoteClassContent content) async {
    if (!_cloud.isAvailable || content.classCode.trim().isEmpty) return false;
    try {
      await _cloud.upsertClassContent(content);
      return true;
    } catch (e, st) {
      debugPrint('syncClassContent failed: $e\n$st');
      return false;
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

  Future<void> startClassContentSync({
    required int classId,
    required String classCode,
    required Future<void> Function(RemoteClassContent? content) onChanged,
  }) async {
    await stopClassContentSync(classId);
    await _cloud.initialize();
    if (!_cloud.isAvailable || classCode.trim().isEmpty) return;

    _lastAppliedClassContentFingerprint.remove(classId);
    _classContentSubscriptions[classId] = _cloud
        .watchClassContentByCode(classCode)
        .listen(
      (content) async {
        if (content == null) return;
        final fingerprint = _classContentFingerprint(content);
        if (_lastAppliedClassContentFingerprint[classId] == fingerprint) {
          return;
        }
        _lastAppliedClassContentFingerprint[classId] = fingerprint;
        try {
          await onChanged(content);
        } catch (e, st) {
          debugPrint('Class content handler failed: $e\n$st');
        }
      },
      onError: (Object e, StackTrace st) {
        debugPrint('Class content sync error: $e\n$st');
      },
    );
  }

  int _classContentFingerprint(RemoteClassContent content) {
    var hash = Object.hash(
      content.updatedAt.millisecondsSinceEpoch,
      content.className,
      content.lessons.length,
    );
    for (final lesson in content.lessons) {
      hash = Object.hash(
        hash,
        lesson.lessonKey,
        lesson.title,
        lesson.sortOrder,
        lesson.phrases.length,
      );
      for (final phrase in lesson.phrases) {
        hash = Object.hash(
          hash,
          phrase.phraseKey,
          phrase.text,
          phrase.sortOrder,
          phrase.imagePath,
        );
      }
    }
    return hash;
  }

  Future<void> stopClassContentSync(int classId) async {
    await _classContentSubscriptions.remove(classId)?.cancel();
    _lastAppliedClassContentFingerprint.remove(classId);
  }

  Future<void> stopAllClassContentSync() async {
    for (final sub in _classContentSubscriptions.values) {
      await sub.cancel();
    }
    _classContentSubscriptions.clear();
    _lastAppliedClassContentFingerprint.clear();
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

  Future<void> updateLearnerReferencesOnCloud({
    required String learnerFirebaseUid,
    required String learnerName,
    String? learnerProfileCode,
  }) async {
    if (!_cloud.isAvailable || learnerFirebaseUid.trim().isEmpty) return;
    await _cloud.updateLearnerReferencesOnCloud(
      learnerFirebaseUid: learnerFirebaseUid,
      learnerName: learnerName,
      learnerProfileCode: learnerProfileCode,
    );
  }

  Future<RemoteUserProfile?> getUserProfileFromCloud(String firebaseUid) async {
    if (!_cloud.isAvailable || firebaseUid.trim().isEmpty) return null;
    return _cloud.getUserProfile(firebaseUid);
  }

  /// Restores account metadata on a new device after Firebase sign-in.
  Future<RemoteUserProfile> resolveUserProfileForLogin({
    required String firebaseUid,
    required String email,
  }) async {
    final normalizedUid = firebaseUid.trim();
    final normalizedEmail = email.trim().toLowerCase();
    final existing = await getUserProfileFromCloud(normalizedUid);
    if (existing != null) {
      final hasName = existing.fullName.trim().isNotEmpty &&
          !AppRepository.isGenericAccountName(existing.fullName);
      final hasFirst = (existing.firstName?.trim().isNotEmpty ?? false);
      if (hasName || hasFirst) return existing;
    }

    if (_cloud.isAvailable) {
      final teacherClasses =
          await _cloud.getTeacherClassesForTeacher(normalizedUid);
      if (teacherClasses.isNotEmpty) {
        return RemoteUserProfile(
          firebaseUid: normalizedUid,
          email: normalizedEmail,
          fullName: '',
          role: 'teacher',
        );
      }

      final parentLinks =
          await _cloud.getParentChildLinksForParent(normalizedUid);
      if (parentLinks.isNotEmpty) {
        return RemoteUserProfile(
          firebaseUid: normalizedUid,
          email: normalizedEmail,
          fullName: '',
          role: 'parent',
        );
      }
    }

    return RemoteUserProfile(
      firebaseUid: normalizedUid,
      email: normalizedEmail,
      fullName: '',
      role: 'learner',
    );
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
      contacts: AppRepository.normalizeEmergencyContacts(contacts),
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

  Future<void> syncLearnerCustomPhrases({
    required String learnerFirebaseUid,
    required List<RemoteLearnerCustomPhrase> phrases,
  }) async {
    if (!_cloud.isAvailable || learnerFirebaseUid.trim().isEmpty) return;
    try {
      await _cloud.upsertLearnerCustomPhrases(
        learnerFirebaseUid: learnerFirebaseUid,
        phrases: phrases,
      );
    } catch (e, st) {
      debugPrint('syncLearnerCustomPhrases failed: $e\n$st');
    }
  }

  Future<List<RemoteLearnerCustomPhrase>> getLearnerCustomPhrasesFromCloud(
    String learnerFirebaseUid,
  ) async {
    if (!_cloud.isAvailable || learnerFirebaseUid.trim().isEmpty) return const [];
    try {
      return await _cloud.getLearnerCustomPhrases(learnerFirebaseUid);
    } catch (e, st) {
      debugPrint('getLearnerCustomPhrasesFromCloud failed: $e\n$st');
      return const [];
    }
  }

  Future<void> syncLearnerFavorites({
    required String learnerFirebaseUid,
    required List<RemoteLearnerFavorite> favorites,
  }) async {
    if (!_cloud.isAvailable || learnerFirebaseUid.trim().isEmpty) return;
    try {
      await _cloud.upsertLearnerFavorites(
        learnerFirebaseUid: learnerFirebaseUid,
        favorites: favorites,
      );
    } catch (e, st) {
      debugPrint('syncLearnerFavorites failed: $e\n$st');
    }
  }

  Future<List<RemoteLearnerFavorite>> getLearnerFavoritesFromCloud(
    String learnerFirebaseUid,
  ) async {
    if (!_cloud.isAvailable || learnerFirebaseUid.trim().isEmpty) return const [];
    try {
      return await _cloud.getLearnerFavorites(learnerFirebaseUid);
    } catch (e, st) {
      debugPrint('getLearnerFavoritesFromCloud failed: $e\n$st');
      return const [];
    }
  }

  Future<void> syncLearnerSpeakHistory({
    required String learnerFirebaseUid,
    required List<RemoteLearnerSpeakHistory> history,
  }) async {
    if (!_cloud.isAvailable || learnerFirebaseUid.trim().isEmpty) return;
    try {
      await _cloud.upsertLearnerSpeakHistory(
        learnerFirebaseUid: learnerFirebaseUid,
        history: history,
      );
    } catch (e, st) {
      debugPrint('syncLearnerSpeakHistory failed: $e\n$st');
    }
  }

  Future<List<RemoteLearnerSpeakHistory>> getLearnerSpeakHistoryFromCloud(
    String learnerFirebaseUid,
  ) async {
    if (!_cloud.isAvailable || learnerFirebaseUid.trim().isEmpty) return const [];
    try {
      return await _cloud.getLearnerSpeakHistory(learnerFirebaseUid);
    } catch (e, st) {
      debugPrint('getLearnerSpeakHistoryFromCloud failed: $e\n$st');
      return const [];
    }
  }

  /// Learner's cloud profile is the source of truth when available; otherwise
  /// uses the teacher device's local copy.
  Future<List<String>> resolveEmergencyContacts({
    required int learnerUserId,
    required List<String> localContacts,
    String? learnerFirebaseUid,
  }) async {
    final normalizedLocal =
        AppRepository.normalizeEmergencyContacts(localContacts);
    final uid = learnerFirebaseUid?.trim();
    if (!_cloud.isAvailable || uid == null || uid.isEmpty) {
      return normalizedLocal;
    }
    try {
      final cloudContacts = AppRepository.normalizeEmergencyContacts(
        await _cloud.getLearnerEmergencyContacts(uid),
      );
      final merged = AppRepository.normalizeEmergencyContacts([
        ...cloudContacts,
        ...normalizedLocal,
      ]);
      if (merged.isNotEmpty) {
        if (merged.join('|') != normalizedLocal.join('|')) {
          await _repository.updateEmergencyContacts(learnerUserId, merged);
        }
        return merged;
      }
    } catch (e, st) {
      debugPrint('Cloud emergency contact fetch failed: $e\n$st');
    }
    return normalizedLocal;
  }

  Future<void> startParentSync({
    required int parentUserId,
    required String parentFirebaseUid,
    required void Function() onChanged,
  }) async {
    await stopParentSync();
    _onParentNotificationsChanged = onChanged;

    await _cloud.initialize();
    if (!_cloud.isAvailable || parentFirebaseUid.trim().isEmpty) {
      debugPrint(
        'Parent notification sync unavailable '
        '(cloud=${_cloud.isAvailable}, uid=${parentFirebaseUid.isNotEmpty}).',
      );
      return;
    }

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

  Future<void> startLearnerEnrollmentSync({
    required String learnerFirebaseUid,
    required void Function() onChanged,
  }) async {
    await stopLearnerEnrollmentSync();
    _onLearnerEnrollmentsChanged = onChanged;
    await _cloud.initialize();
    if (!_cloud.isAvailable || learnerFirebaseUid.trim().isEmpty) return;

    _learnerEnrollmentSubscription = _cloud
        .watchClassEnrollmentsForLearner(learnerFirebaseUid)
        .listen(
      (_) => _onLearnerEnrollmentsChanged?.call(),
      onError: (Object e, StackTrace st) {
        debugPrint('Learner enrollment sync error: $e\n$st');
      },
    );
  }

  Future<void> stopLearnerEnrollmentSync() async {
    await _learnerEnrollmentSubscription?.cancel();
    _learnerEnrollmentSubscription = null;
    _onLearnerEnrollmentsChanged = null;
  }

  Future<void> startTeacherMonitoringSync({
    required String teacherFirebaseUid,
    required void Function(List<RemoteClassEnrollment>) onEnrollmentsChanged,
    required void Function(List<RemoteTeacherClass>) onClassesChanged,
  }) async {
    await stopTeacherMonitoringSync();
    _onTeacherEnrollmentsChanged = onEnrollmentsChanged;
    _onTeacherClassesChanged = onClassesChanged;
    await _cloud.initialize();
    if (!_cloud.isAvailable || teacherFirebaseUid.trim().isEmpty) return;

    _teacherEnrollmentSubscription = _cloud
        .watchClassEnrollmentsForTeacher(teacherFirebaseUid)
        .listen(
      (items) => _onTeacherEnrollmentsChanged?.call(items),
      onError: (Object e, StackTrace st) {
        debugPrint('Teacher enrollment sync error: $e\n$st');
      },
    );

    _teacherClassSubscription = _cloud
        .watchTeacherClassesForTeacher(teacherFirebaseUid)
        .listen(
      (items) => _onTeacherClassesChanged?.call(items),
      onError: (Object e, StackTrace st) {
        debugPrint('Teacher class sync error: $e\n$st');
      },
    );
  }

  Future<void> stopTeacherMonitoringSync() async {
    await _teacherEnrollmentSubscription?.cancel();
    _teacherEnrollmentSubscription = null;
    _onTeacherEnrollmentsChanged = null;
    await _teacherClassSubscription?.cancel();
    _teacherClassSubscription = null;
    _onTeacherClassesChanged = null;
  }

  Future<void> syncTeacherAlertsFromCloud({
    required int teacherUserId,
    required String teacherFirebaseUid,
  }) async {
    if (!_cloud.isAvailable ||
        teacherUserId <= 0 ||
        teacherFirebaseUid.trim().isEmpty) {
      return;
    }
    try {
      final remote = await _cloud.getTeacherAlerts(
        teacherUserId: teacherUserId,
        teacherFirebaseUid: teacherFirebaseUid,
      );
      await _repository.mergeRemoteTeacherAlerts(
        teacherUserId: teacherUserId,
        items: remote,
      );
    } catch (e, st) {
      debugPrint('Teacher alerts cloud pull failed: $e\n$st');
    }
  }

  Future<void> startTeacherAlertSync({
    required int teacherUserId,
    required String teacherFirebaseUid,
    required void Function() onChanged,
  }) async {
    await stopTeacherAlertSync();
    _onTeacherAlertsChanged = onChanged;
    await _cloud.initialize();
    if (!_cloud.isAvailable ||
        teacherUserId <= 0 ||
        teacherFirebaseUid.trim().isEmpty) {
      return;
    }

    await syncTeacherAlertsFromCloud(
      teacherUserId: teacherUserId,
      teacherFirebaseUid: teacherFirebaseUid,
    );
    _onTeacherAlertsChanged?.call();

    _teacherAlertSubscription = _cloud
        .watchTeacherAlerts(
          teacherUserId: teacherUserId,
          teacherFirebaseUid: teacherFirebaseUid,
        )
        .listen(
      (remoteItems) async {
        await _repository.mergeRemoteTeacherAlerts(
          teacherUserId: teacherUserId,
          items: remoteItems,
        );
        _onTeacherAlertsChanged?.call();
      },
      onError: (Object e, StackTrace st) {
        debugPrint('Teacher alert sync error: $e\n$st');
      },
    );
  }

  Future<void> stopTeacherAlertSync() async {
    await _teacherAlertSubscription?.cancel();
    _teacherAlertSubscription = null;
    _onTeacherAlertsChanged = null;
  }

  Future<void> startParentChildLinkSync({
    required String parentFirebaseUid,
    required void Function() onChanged,
  }) async {
    await stopParentChildLinkSync();
    _onParentChildLinksChanged = onChanged;
    await _cloud.initialize();
    if (!_cloud.isAvailable || parentFirebaseUid.trim().isEmpty) return;

    _parentChildLinkSubscription = _cloud
        .watchParentChildLinks(parentFirebaseUid)
        .listen(
      (_) => _onParentChildLinksChanged?.call(),
      onError: (Object e, StackTrace st) {
        debugPrint('Parent child link sync error: $e\n$st');
      },
    );
  }

  Future<void> stopParentChildLinkSync() async {
    await _parentChildLinkSubscription?.cancel();
    _parentChildLinkSubscription = null;
    _onParentChildLinksChanged = null;
  }

  Future<void> startPersonalBoardSync({
    required String learnerFirebaseUid,
    required void Function(RemoteLearnerPersonalBoardSnapshot snapshot) onChanged,
  }) async {
    await stopPersonalBoardSync();
    _onPersonalBoardChanged = onChanged;
    await _cloud.initialize();
    if (!_cloud.isAvailable || learnerFirebaseUid.trim().isEmpty) {
      debugPrint(
        'Personal board sync unavailable '
        '(cloud=${_cloud.isAvailable}, uid=${learnerFirebaseUid.isNotEmpty}).',
      );
      return;
    }

    _personalBoardSubscription = _cloud
        .watchLearnerPersonalBoard(learnerFirebaseUid)
        .listen(
      (snapshot) => _onPersonalBoardChanged?.call(snapshot),
      onError: (Object e, StackTrace st) {
        debugPrint('Personal board sync error: $e\n$st');
      },
    );
  }

  Future<void> stopPersonalBoardSync() async {
    await _personalBoardSubscription?.cancel();
    _personalBoardSubscription = null;
    _onPersonalBoardChanged = null;
  }

  Future<void> startUserProfileSync({
    required String firebaseUid,
    required void Function(RemoteUserProfile profile) onChanged,
  }) async {
    await stopUserProfileSync();
    _onUserProfileChanged = onChanged;
    await _cloud.initialize();
    if (!_cloud.isAvailable || firebaseUid.trim().isEmpty) {
      debugPrint(
        'User profile sync unavailable '
        '(cloud=${_cloud.isAvailable}, uid=${firebaseUid.isNotEmpty}).',
      );
      return;
    }

    _userProfileSubscription = _cloud.watchUserProfile(firebaseUid).listen(
      (profile) => _onUserProfileChanged?.call(profile),
      onError: (Object e, StackTrace st) {
        debugPrint('User profile sync error: $e\n$st');
      },
    );
  }

  Future<void> stopUserProfileSync() async {
    await _userProfileSubscription?.cancel();
    _userProfileSubscription = null;
    _onUserProfileChanged = null;
  }

  Future<void> stopMonitoringSync() async {
    await stopLearnerEnrollmentSync();
    await stopTeacherMonitoringSync();
    await stopTeacherAlertSync();
    await stopParentChildLinkSync();
    await stopPersonalBoardSync();
    await stopUserProfileSync();
    await stopAllMonitoredLearnerActivitySync();
    await stopAllClassContentSync();
  }

  Future<void> dispose() async {
    await stopParentSync();
    await stopMonitoringSync();
    await _cloud.dispose();
  }
}
