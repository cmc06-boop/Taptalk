import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'cloud_notification_backend.dart';
import 'firebase_service.dart';
import '../data/repositories/app_repository.dart';

/// Firestore-backed notifications for cross-device parent alerts.
class FirestoreNotificationBackend implements CloudNotificationBackend {
  static const String collectionName = 'parent_notifications';
  static const String linkCollectionName = 'parent_child_links';
  static const String enrollmentCollectionName = 'class_enrollments_cloud';
  static const String joinRequestCollectionName = 'class_join_requests_cloud';
  static const String teacherClassCollectionName = 'teacher_classes_cloud';
  static const String learnerProfileCollectionName = 'learner_profiles';
  static const String userProfileCollectionName = 'user_profiles';
  static const String activityCollectionName = 'learner_activity';

  @override
  bool get isAvailable => FirebaseService.instance.isAvailable;

  /// Live signed-in Firebase uid; waits briefly for auth restore after startup.
  Future<String?> _liveAuthUid() async {
    var uid = FirebaseService.instance.currentUid?.trim() ?? '';
    if (uid.isNotEmpty) return uid;
    uid = (await FirebaseService.instance.waitForAuthUid())?.trim() ?? '';
    return uid.isEmpty ? null : uid;
  }

  @override
  Future<void> initialize() async {
    await FirebaseService.instance.initialize();
  }

  @override
  Future<String?> publishTeacherAlert(TeacherAlertCloudEvent event) async {
    if (!isAvailable) return null;
    if (event.parentFirebaseUid.trim().isEmpty) {
      debugPrint('Skipping cloud alert: parent has no Firebase account linked.');
      return null;
    }

    final payload = event.toFirestoreMap()
      ..['parentFirebaseUid'] = event.parentFirebaseUid
      ..['createdAt'] = Timestamp.fromDate(event.createdAt.toUtc());

    final doc = await FirebaseFirestore.instance
        .collection(collectionName)
        .add(payload);
    return doc.id;
  }

  @override
  Future<void> upsertParentChildLink({
    required int parentUserId,
    required int learnerUserId,
    required String parentFirebaseUid,
    required String learnerFirebaseUid,
    String? learnerName,
    String? learnerProfileCode,
  }) async {
    if (!isAvailable ||
        parentFirebaseUid.trim().isEmpty ||
        learnerFirebaseUid.trim().isEmpty) {
      return;
    }
    final docId = '${parentFirebaseUid.trim()}_${learnerFirebaseUid.trim()}';
    final payload = <String, Object?>{
      'parentUserId': parentUserId,
      'learnerUserId': learnerUserId,
      'parentFirebaseUid': parentFirebaseUid.trim(),
      'learnerFirebaseUid': learnerFirebaseUid.trim(),
      'linkedAt': FieldValue.serverTimestamp(),
    };
    final name = learnerName?.trim();
    if (name != null && name.isNotEmpty) {
      payload['learnerName'] = name;
    }
    final code = learnerProfileCode?.trim();
    if (code != null && code.isNotEmpty) {
      payload['learnerProfileCode'] = code;
    }
    await FirebaseFirestore.instance
        .collection(linkCollectionName)
        .doc(docId)
        .set(payload, SetOptions(merge: true));
  }

  @override
  Future<void> removeParentChildLink({
    required String parentFirebaseUid,
    required String learnerFirebaseUid,
  }) async {
    if (!isAvailable ||
        parentFirebaseUid.trim().isEmpty ||
        learnerFirebaseUid.trim().isEmpty) {
      return;
    }
    final docId = '${parentFirebaseUid.trim()}_${learnerFirebaseUid.trim()}';
    await FirebaseFirestore.instance
        .collection(linkCollectionName)
        .doc(docId)
        .delete();
  }

  @override
  Future<List<String>> getLinkedParentFirebaseUids(
    String learnerFirebaseUid,
  ) async {
    if (!isAvailable || learnerFirebaseUid.trim().isEmpty) return const [];
    final snapshot = await FirebaseFirestore.instance
        .collection(linkCollectionName)
        .where('learnerFirebaseUid', isEqualTo: learnerFirebaseUid.trim())
        .get();
    return snapshot.docs
        .map((doc) => (doc.data()['parentFirebaseUid'] as String?) ?? '')
        .where((uid) => uid.trim().isNotEmpty)
        .map((uid) => uid.trim())
        .toSet()
        .toList();
  }

  @override
  Future<void> upsertClassEnrollment(ClassEnrollmentCloudEvent event) async {
    if (!isAvailable ||
        event.classCode.trim().isEmpty ||
        event.learnerFirebaseUid.trim().isEmpty) {
      return;
    }
    final classCode =
        AppRepository.normalizeClassCode(event.classCode);
    final learnerUid = event.learnerFirebaseUid.trim();
    final docId = '${classCode}_$learnerUid';
    final payload = event.toFirestoreMap()
      ..['classCode'] = classCode
      ..['enrolledAt'] = Timestamp.fromDate(event.enrolledAt.toUtc());
    await FirebaseFirestore.instance
        .collection(enrollmentCollectionName)
        .doc(docId)
        .set(payload);
  }

  @override
  Future<void> removeClassEnrollment({
    required String classCode,
    required String learnerFirebaseUid,
  }) async {
    if (!isAvailable ||
        classCode.trim().isEmpty ||
        learnerFirebaseUid.trim().isEmpty) {
      return;
    }
    final normalized = AppRepository.normalizeClassCode(classCode);
    final docId = '${normalized}_${learnerFirebaseUid.trim()}';
    await FirebaseFirestore.instance
        .collection(enrollmentCollectionName)
        .doc(docId)
        .delete();
  }

  @override
  Future<void> upsertClassJoinRequest(ClassJoinRequestCloudEvent event) async {
    if (!isAvailable ||
        event.classCode.trim().isEmpty ||
        event.learnerFirebaseUid.trim().isEmpty) {
      return;
    }
    final classCode = AppRepository.normalizeClassCode(event.classCode);
    final authUid = FirebaseService.instance.currentUid?.trim() ?? '';
    final eventLearnerUid = event.learnerFirebaseUid.trim();
    final eventTeacherUid = event.teacherFirebaseUid.trim();
    // Student send: stamp live Auth uid. Teacher accept/reject: keep the
    // original learner uid so the same cloud document is updated.
    final learnerUid = (authUid.isNotEmpty && authUid != eventTeacherUid)
        ? authUid
        : eventLearnerUid;
    final docId = '${classCode}_$learnerUid';
    final payload = event.toFirestoreMap()
      ..['classCode'] = classCode
      ..['learnerFirebaseUid'] = learnerUid
      ..['teacherFirebaseUid'] = event.teacherFirebaseUid.trim()
      ..['requestedAt'] = Timestamp.fromDate(event.requestedAt.toUtc());
    if (event.respondedAt != null) {
      payload['respondedAt'] =
          Timestamp.fromDate(event.respondedAt!.toUtc());
    }
    await FirebaseFirestore.instance
        .collection(joinRequestCollectionName)
        .doc(docId)
        .set(payload);
  }

  @override
  Future<List<RemoteClassJoinRequest>> getClassJoinRequestsForTeacher(
    String teacherFirebaseUid, {
    Iterable<String> classCodes = const [],
  }) async {
    if (!isAvailable) return const [];
    final uid = teacherFirebaseUid.trim();
    final codes = classCodes
        .map(AppRepository.normalizeClassCode)
        .where(AppRepository.isValidClassCodeFormat)
        .toSet();
    if (uid.isEmpty && codes.isEmpty) return const [];

    bool matches(RemoteClassJoinRequest request) {
      if (uid.isNotEmpty && request.teacherFirebaseUid.trim() == uid) {
        return true;
      }
      return codes.contains(
        AppRepository.normalizeClassCode(request.classCode),
      );
    }

    List<RemoteClassJoinRequest> parseDocs(
      Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    ) {
      final requests = <RemoteClassJoinRequest>[];
      for (final doc in docs) {
        try {
          final request = _joinRequestFromDocument(doc);
          if (matches(request)) requests.add(request);
        } catch (e, st) {
          debugPrint('Skip join request ${doc.id}: $e\n$st');
        }
      }
      return requests;
    }

    if (uid.isNotEmpty && codes.isEmpty) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection(joinRequestCollectionName)
            .where('teacherFirebaseUid', isEqualTo: uid)
            .get();
        if (snapshot.docs.isNotEmpty) {
          return parseDocs(snapshot.docs);
        }
      } catch (e, st) {
        debugPrint('getClassJoinRequestsForTeacher query failed: $e\n$st');
      }
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(joinRequestCollectionName)
          .get();
      return parseDocs(snapshot.docs);
    } catch (e, st) {
      debugPrint('getClassJoinRequestsForTeacher fallback failed: $e\n$st');
      return const [];
    }
  }

  @override
  Future<List<RemoteClassJoinRequest>> getClassJoinRequestsForLearner(
    String learnerFirebaseUid,
  ) async {
    if (!isAvailable || learnerFirebaseUid.trim().isEmpty) return const [];
    final snapshot = await FirebaseFirestore.instance
        .collection(joinRequestCollectionName)
        .where('learnerFirebaseUid', isEqualTo: learnerFirebaseUid.trim())
        .get();
    return snapshot.docs.map(_joinRequestFromDocument).toList();
  }

  @override
  Stream<List<RemoteClassJoinRequest>> watchClassJoinRequestsForTeacher(
    String teacherFirebaseUid,
  ) {
    if (!isAvailable || teacherFirebaseUid.trim().isEmpty) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection(joinRequestCollectionName)
        .where('teacherFirebaseUid', isEqualTo: teacherFirebaseUid.trim())
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(_joinRequestFromDocument).toList(),
        );
  }

  @override
  Stream<List<RemoteClassJoinRequest>> watchClassJoinRequestsForLearner(
    String learnerFirebaseUid,
  ) {
    if (!isAvailable || learnerFirebaseUid.trim().isEmpty) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection(joinRequestCollectionName)
        .where('learnerFirebaseUid', isEqualTo: learnerFirebaseUid.trim())
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(_joinRequestFromDocument).toList(),
        );
  }

  @override
  Future<List<RemoteClassEnrollment>> getClassEnrollmentsForTeacher(
    String teacherFirebaseUid,
  ) async {
    if (!isAvailable || teacherFirebaseUid.trim().isEmpty) return const [];
    final snapshot = await FirebaseFirestore.instance
        .collection(enrollmentCollectionName)
        .where('teacherFirebaseUid', isEqualTo: teacherFirebaseUid.trim())
        .get();
    return snapshot.docs.map(_enrollmentFromDocument).toList();
  }

  @override
  Future<List<RemoteClassEnrollment>> getClassEnrollmentsForLearner(
    String learnerFirebaseUid,
  ) async {
    if (!isAvailable || learnerFirebaseUid.trim().isEmpty) return const [];
    final snapshot = await FirebaseFirestore.instance
        .collection(enrollmentCollectionName)
        .where('learnerFirebaseUid', isEqualTo: learnerFirebaseUid.trim())
        .get();
    return snapshot.docs.map(_enrollmentFromDocument).toList();
  }

  @override
  Future<void> appendLearnerActivity(LearnerActivityCloudEvent event) async {
    if (!isAvailable || event.learnerFirebaseUid.trim().isEmpty) return;
    final payload = event.toFirestoreMap()
      ..['createdAt'] = Timestamp.fromDate(event.createdAt.toUtc());
    // Each tap is its own document so usage counts stay accurate.
    await FirebaseFirestore.instance
        .collection(activityCollectionName)
        .add(payload);
  }

  @override
  Future<List<RemoteLearnerActivity>> getLearnerActivities({
    required String learnerFirebaseUid,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    if (!isAvailable || learnerFirebaseUid.trim().isEmpty) return const [];
    try {
      final rangeStartUtc = rangeStart.toUtc();
      final rangeEndUtc = rangeEnd.toUtc();
      // Single-field query only — avoids requiring a composite Firestore index.
      // Date range is applied client-side below.
      final snapshot = await FirebaseFirestore.instance
          .collection(activityCollectionName)
          .where('learnerFirebaseUid', isEqualTo: learnerFirebaseUid.trim())
          .get();
      final activities = <RemoteLearnerActivity>[];
      for (final doc in snapshot.docs) {
        final activity = _activityFromDocument(doc);
        if (activity == null) continue;
        final createdAtUtc = activity.createdAt.toUtc();
        if (createdAtUtc.isBefore(rangeStartUtc) ||
            !createdAtUtc.isBefore(rangeEndUtc)) {
          continue;
        }
        activities.add(activity);
      }
      activities.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return activities;
    } catch (e, st) {
      debugPrint('getLearnerActivities failed: $e\n$st');
      return const [];
    }
  }

  @override
  Stream<List<RemoteLearnerActivity>> watchLearnerActivities(
    String learnerFirebaseUid,
  ) {
    if (!isAvailable || learnerFirebaseUid.trim().isEmpty) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection(activityCollectionName)
        .where('learnerFirebaseUid', isEqualTo: learnerFirebaseUid.trim())
        .snapshots()
        .map((snapshot) {
      final activities = <RemoteLearnerActivity>[];
      final seen = <String>{};
      void absorb(DocumentSnapshot<Map<String, dynamic>> doc) {
        final activity = _activityFromDocument(doc);
        if (activity == null) return;
        final key =
            '${activity.createdAt.millisecondsSinceEpoch}|'
            '${activity.phraseText.trim().toLowerCase()}|'
            '${activity.categoryKey}';
        if (!seen.add(key)) return;
        activities.add(activity);
      }

      for (final doc in snapshot.docs) {
        absorb(doc);
      }
      return activities;
    });
  }

  RemoteLearnerActivity? _activityFromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) return null;
    final createdAt = _readTimestamp(data['createdAt']);
    return RemoteLearnerActivity(
      phraseText: (data['phraseText'] as String?) ?? '',
      categoryKey: (data['categoryKey'] as String?) ?? '',
      createdAt: createdAt.toLocal(),
      className: data['className'] as String?,
      lessonTitle: data['lessonTitle'] as String?,
    );
  }

  @override
  Future<void> upsertClassContent(RemoteClassContent content) async {
    if (!isAvailable ||
        content.classCode.trim().isEmpty ||
        content.className.trim().isEmpty ||
        content.teacherFirebaseUid.trim().isEmpty) {
      throw StateError('Class content upsert unavailable or invalid payload');
    }
    final docId = AppRepository.normalizeClassCode(content.classCode);
    final className = content.className.trim();
    final teacherUid = await _liveAuthUid();
    if (teacherUid == null) {
      throw StateError('Class content upsert missing Firebase auth session');
    }
    // Ensure class metadata exists before merging lessons (merge never deletes fields).
    await FirebaseFirestore.instance
        .collection(teacherClassCollectionName)
        .doc(docId)
        .set(
          {
            'classCode': docId,
            'className': className,
            'teacherFirebaseUid': teacherUid,
          },
          SetOptions(merge: true),
        )
        .timeout(const Duration(seconds: 8));
    final payload = <String, Object?>{
      'classCode': docId,
      'className': className,
      'teacherFirebaseUid': teacherUid,
      'contentUpdatedAt': Timestamp.fromDate(content.updatedAt.toUtc()),
      'lessons': content.lessons.map((lesson) {
        return <String, Object?>{
          'lessonKey': lesson.lessonKey,
          'title': lesson.title,
          'sortOrder': lesson.sortOrder,
          'createdAt': lesson.createdAt.toUtc().toIso8601String(),
          'phrases': lesson.phrases.map((phrase) {
            return <String, Object?>{
              'phraseKey': phrase.phraseKey,
              'text': phrase.text,
              'sortOrder': phrase.sortOrder,
              if (phrase.imagePath != null && phrase.imagePath!.trim().isNotEmpty)
                'imagePath': phrase.imagePath!.trim(),
            };
          }).toList(),
        };
      }).toList(),
    };
    // Store lessons on the existing teacher_classes_cloud doc (rules already deployed).
    await FirebaseFirestore.instance
        .collection(teacherClassCollectionName)
        .doc(docId)
        .set(payload, SetOptions(merge: true))
        .timeout(const Duration(seconds: 8));
  }

  @override
  Future<RemoteClassContent?> getClassContentByCode(String classCode) async {
    if (!isAvailable || classCode.trim().isEmpty) return null;
    try {
      final docId = AppRepository.normalizeClassCode(classCode);
      final doc = await FirebaseFirestore.instance
          .collection(teacherClassCollectionName)
          .doc(docId)
          .get();
      if (!doc.exists) return null;
      return _classContentFromDocument(docId, doc.data() ?? {});
    } catch (e, st) {
      debugPrint('getClassContentByCode failed: $e\n$st');
      return null;
    }
  }

  @override
  Stream<RemoteClassContent?> watchClassContentByCode(String classCode) {
    if (!isAvailable || classCode.trim().isEmpty) {
      return const Stream.empty();
    }
    final docId = AppRepository.normalizeClassCode(classCode);
    return FirebaseFirestore.instance
        .collection(teacherClassCollectionName)
        .doc(docId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return _classContentFromDocument(docId, doc.data() ?? {});
    });
  }

  RemoteClassContent _classContentFromDocument(
    String classCode,
    Map<String, dynamic> data,
  ) {
    final lessonsRaw = data['lessons'];
    final lessons = <RemoteClassLessonContent>[];
    if (lessonsRaw is List) {
      for (final rawLesson in lessonsRaw) {
        if (rawLesson is! Map) continue;
        final lessonMap = Map<String, dynamic>.from(rawLesson);
        final phrasesRaw = lessonMap['phrases'];
        final phrases = <RemoteLessonPhraseContent>[];
        if (phrasesRaw is List) {
          for (final rawPhrase in phrasesRaw) {
            if (rawPhrase is! Map) continue;
            final phraseMap = Map<String, dynamic>.from(rawPhrase);
            phrases.add(
              RemoteLessonPhraseContent(
                phraseKey: (phraseMap['phraseKey'] as String?) ?? '',
                text: (phraseMap['text'] as String?) ?? '',
                sortOrder: phraseMap['sortOrder'] as int? ?? 0,
                imagePath: phraseMap['imagePath'] as String?,
              ),
            );
          }
        }
        phrases.sort((a, b) {
          final byOrder = a.sortOrder.compareTo(b.sortOrder);
          return byOrder != 0 ? byOrder : a.phraseKey.compareTo(b.phraseKey);
        });
        lessons.add(
          RemoteClassLessonContent(
            lessonKey: (lessonMap['lessonKey'] as String?) ?? '',
            title: (lessonMap['title'] as String?) ?? '',
            sortOrder: lessonMap['sortOrder'] as int? ?? 0,
            createdAt: _readTimestamp(lessonMap['createdAt']),
            phrases: phrases,
          ),
        );
      }
    }
    lessons.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.lessonKey.compareTo(b.lessonKey);
    });
    return RemoteClassContent(
      classCode: classCode,
      className: (data['className'] as String?) ?? '',
      teacherFirebaseUid: (data['teacherFirebaseUid'] as String?) ?? '',
      updatedAt: _readTimestamp(data['contentUpdatedAt'] ?? data['updatedAt']),
      lessons: lessons,
    );
  }

  @override
  Future<void> upsertTeacherClass(TeacherClassCloudEvent event) async {
    if (!isAvailable || event.classCode.trim().isEmpty) {
      return;
    }
    final authUid = await _liveAuthUid();
    if (authUid == null) return;
    final docId = AppRepository.normalizeClassCode(event.classCode);
    final className = event.className.trim().isEmpty
        ? 'Class'
        : event.className.trim();
    final payload = event.toFirestoreMap()
      ..['createdAt'] = Timestamp.fromDate(event.createdAt.toUtc())
      ..['classCode'] = docId
      ..['className'] = className
      ..['teacherFirebaseUid'] = authUid;
    await FirebaseFirestore.instance
        .collection(teacherClassCollectionName)
        .doc(docId)
        .set(payload, SetOptions(merge: true))
        .timeout(const Duration(seconds: 8));
  }

  @override
  Future<void> removeTeacherClass({required String classCode}) async {
    if (!isAvailable || classCode.trim().isEmpty) return;
    final docId = AppRepository.normalizeClassCode(classCode);
    final docRef = FirebaseFirestore.instance
        .collection(teacherClassCollectionName)
        .doc(docId);
    final authUid = await _liveAuthUid();
    if (authUid == null) return;
    try {
      final doc = await docRef.get();
      if (doc.exists) {
        final owner = (doc.data()?['teacherFirebaseUid'] as String?)?.trim() ?? '';
        if (owner != authUid) {
          await docRef.set(
            {
              'teacherFirebaseUid': authUid,
              'classCode': docId,
              'className': (doc.data()?['className'] as String?) ?? 'Class',
            },
            SetOptions(merge: true),
          );
        }
      }
      await docRef.delete();
    } catch (e, st) {
      debugPrint('removeTeacherClass failed: $e\n$st');
    }
    await removeClassEnrollmentsForClass(classCode: classCode);
    final codesToMatch = {
      docId,
      classCode.trim(),
      classCode.trim().toUpperCase(),
    };
    Future<void> deleteJoinDocs(
      Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    ) async {
      for (final doc in docs) {
        try {
          if (authUid.isNotEmpty) {
            await doc.reference.set(
              {'teacherFirebaseUid': authUid},
              SetOptions(merge: true),
            );
          }
          await doc.reference.delete();
        } catch (e, st) {
          debugPrint('remove join request ${doc.id} failed: $e\n$st');
        }
      }
    }

    try {
      for (final code in codesToMatch) {
        if (code.isEmpty) continue;
        final snapshot = await FirebaseFirestore.instance
            .collection(joinRequestCollectionName)
            .where('classCode', isEqualTo: code)
            .get();
        await deleteJoinDocs(snapshot.docs);
      }
    } catch (e, st) {
      debugPrint('remove join requests for class failed: $e\n$st');
    }
  }

  @override
  Future<void> removeClassEnrollmentsForClass({required String classCode}) async {
    if (!isAvailable || classCode.trim().isEmpty) return;
    final normalized = AppRepository.normalizeClassCode(classCode);
    final codesToMatch = {
      normalized,
      classCode.trim(),
      classCode.trim().toUpperCase(),
    };
    final authUid = FirebaseService.instance.currentUid?.trim() ?? '';
    Future<void> deleteDocs(
      Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    ) async {
      for (final doc in docs) {
        try {
          if (authUid.isNotEmpty) {
            await doc.reference.set(
              {'teacherFirebaseUid': authUid},
              SetOptions(merge: true),
            );
          }
          await doc.reference.delete();
        } catch (e, st) {
          debugPrint('remove enrollment ${doc.id} failed: $e\n$st');
        }
      }
    }

    try {
      for (final code in codesToMatch) {
        if (code.isEmpty) continue;
        final snapshot = await FirebaseFirestore.instance
            .collection(enrollmentCollectionName)
            .where('classCode', isEqualTo: code)
            .get();
        await deleteDocs(snapshot.docs);
      }
    } catch (e, st) {
      debugPrint('removeClassEnrollmentsForClass query failed: $e\n$st');
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection(enrollmentCollectionName)
            .get();
        await deleteDocs(
          snapshot.docs.where((doc) {
            final code = AppRepository.normalizeClassCode(
              (doc.data()['classCode'] as String?) ?? '',
            );
            return codesToMatch.contains(code) ||
                codesToMatch.contains((doc.data()['classCode'] as String?) ?? '');
          }),
        );
      } catch (e2, st2) {
        debugPrint('removeClassEnrollmentsForClass fallback failed: $e2\n$st2');
      }
    }
  }

  @override
  Future<List<RemoteTeacherClass>> getTeacherClassesForTeacher(
    String teacherFirebaseUid,
  ) async {
    if (!isAvailable || teacherFirebaseUid.trim().isEmpty) return const [];
    final snapshot = await FirebaseFirestore.instance
        .collection(teacherClassCollectionName)
        .where('teacherFirebaseUid', isEqualTo: teacherFirebaseUid.trim())
        .get();
    return snapshot.docs.map(_teacherClassFromDocument).toList();
  }

  @override
  Future<RemoteTeacherClass?> getTeacherClassByCode(String classCode) async {
    if (!isAvailable || classCode.trim().isEmpty) return null;
    try {
      final docId = AppRepository.normalizeClassCode(classCode);
      final doc = await FirebaseFirestore.instance
          .collection(teacherClassCollectionName)
          .doc(docId)
          .get();
      if (doc.exists) return _teacherClassFromDocument(doc);

      // Same approach as profile-code lookup: match the field, not only doc id.
      for (final value in <String>{
        docId,
        classCode.trim(),
        classCode.trim().toUpperCase(),
      }) {
        if (value.isEmpty) continue;
        final snapshot = await FirebaseFirestore.instance
            .collection(teacherClassCollectionName)
            .where('classCode', isEqualTo: value)
            .limit(1)
            .get();
        if (snapshot.docs.isNotEmpty) {
          return _teacherClassFromDocument(snapshot.docs.first);
        }
      }
      return null;
    } catch (e, st) {
      debugPrint('getTeacherClassByCode failed: $e\n$st');
      return null;
    }
  }

  @override
  Future<RemoteLearnerProfile?> findLearnerByProfileCode(
    String profileCode,
  ) async {
    if (!isAvailable || profileCode.trim().isEmpty) return null;
    try {
      final normalized = AppRepository.normalizeProfileCode(profileCode);
      final snapshot = await FirebaseFirestore.instance
          .collection(learnerProfileCollectionName)
          .where('profileCode', isEqualTo: normalized)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return _learnerProfileFromDocument(snapshot.docs.first);
      }

      final userSnapshot = await FirebaseFirestore.instance
          .collection(userProfileCollectionName)
          .where('profileCode', isEqualTo: normalized)
          .where('role', isEqualTo: 'learner')
          .limit(1)
          .get();
      if (userSnapshot.docs.isEmpty) return null;
      final doc = userSnapshot.docs.first;
      final data = doc.data();
      return RemoteLearnerProfile(
        learnerFirebaseUid: doc.id,
        learnerName: (data['fullName'] as String?) ?? '',
        profileCode: normalized,
        learnerUserId: 0,
      );
    } catch (e, st) {
      debugPrint('findLearnerByProfileCode failed: $e\n$st');
      return null;
    }
  }

  @override
  Future<List<RemoteParentChildLink>> getParentChildLinksForParent(
    String parentFirebaseUid,
  ) async {
    if (!isAvailable || parentFirebaseUid.trim().isEmpty) return const [];
    final snapshot = await FirebaseFirestore.instance
        .collection(linkCollectionName)
        .where('parentFirebaseUid', isEqualTo: parentFirebaseUid.trim())
        .get();
    return snapshot.docs.map(_parentChildLinkFromDocument).toList();
  }

  @override
  Future<void> upsertUserProfile(RemoteUserProfile profile) async {
    if (!isAvailable || profile.firebaseUid.trim().isEmpty) return;
    final payload = <String, Object?>{
      'firebaseUid': profile.firebaseUid.trim(),
      'email': profile.email.trim().toLowerCase(),
      'fullName': profile.fullName.trim(),
      'role': profile.role,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final firstName = profile.firstName?.trim();
    if (firstName != null && firstName.isNotEmpty) {
      payload['firstName'] = firstName;
    }
    if (profile.themeKey != null && profile.themeKey!.trim().isNotEmpty) {
      payload['themeKey'] = profile.themeKey!.trim();
    }
    if (profile.language != null && profile.language!.trim().isNotEmpty) {
      payload['language'] = profile.language!.trim();
    }
    if (profile.ttsSpeed != null) {
      payload['ttsSpeed'] = profile.ttsSpeed;
    }
    if (profile.profileCode != null && profile.profileCode!.trim().isNotEmpty) {
      payload['profileCode'] = AppRepository.normalizeProfileCode(
        profile.profileCode!,
      );
    }
    final address = profile.address?.trim();
    if (address != null && address.isNotEmpty) {
      payload['address'] = address;
    }
    if (profile.age != null) {
      payload['age'] = profile.age;
    }
    final gradeLevel = profile.gradeLevel?.trim();
    if (gradeLevel != null && gradeLevel.isNotEmpty) {
      payload['gradeLevel'] = gradeLevel;
    }
    final birthdate = profile.birthdate?.trim();
    if (birthdate != null && birthdate.isNotEmpty) {
      payload['birthdate'] = birthdate;
    }
    final lastName = profile.lastName?.trim();
    if (lastName != null) {
      payload['lastName'] = lastName;
    }
    await FirebaseFirestore.instance
        .collection(userProfileCollectionName)
        .doc(profile.firebaseUid.trim())
        .set(payload, SetOptions(merge: true));
  }

  @override
  Future<void> updateLearnerReferencesOnCloud({
    required String learnerFirebaseUid,
    required String learnerName,
    String? learnerProfileCode,
  }) async {
    if (!isAvailable || learnerFirebaseUid.trim().isEmpty) return;
    final uid = learnerFirebaseUid.trim();
    final name = learnerName.trim();
    if (name.isEmpty) return;

    final payload = <String, Object?>{
      'learnerName': name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final code = learnerProfileCode?.trim();
    if (code != null && code.isNotEmpty) {
      payload['learnerProfileCode'] = AppRepository.normalizeProfileCode(code);
    }

    await _mergeWhere(
      collection: linkCollectionName,
      field: 'learnerFirebaseUid',
      uid: uid,
      payload: payload,
    );
    await _mergeWhere(
      collection: enrollmentCollectionName,
      field: 'learnerFirebaseUid',
      uid: uid,
      payload: {
        'learnerName': name,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    await _mergeWhere(
      collection: joinRequestCollectionName,
      field: 'learnerFirebaseUid',
      uid: uid,
      payload: {
        'learnerName': name,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    await _mergeWhere(
      collection: learnerProfileCollectionName,
      field: 'learnerFirebaseUid',
      uid: uid,
      payload: {
        'learnerName': name,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  @override
  Future<void> updateTeacherNameReferencesOnCloud({
    required String teacherFirebaseUid,
    required String teacherName,
  }) async {
    if (!isAvailable || teacherFirebaseUid.trim().isEmpty) return;
    final uid = teacherFirebaseUid.trim();
    final name = teacherName.trim();
    if (name.isEmpty || AppRepository.isGenericAccountName(name)) return;

    final payload = <String, Object?>{
      'teacherName': name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _mergeWhere(
      collection: teacherClassCollectionName,
      field: 'teacherFirebaseUid',
      uid: uid,
      payload: payload,
    );
    await _mergeWhere(
      collection: enrollmentCollectionName,
      field: 'teacherFirebaseUid',
      uid: uid,
      payload: payload,
    );
    await _mergeWhere(
      collection: joinRequestCollectionName,
      field: 'teacherFirebaseUid',
      uid: uid,
      payload: payload,
    );
  }

  Future<void> _mergeWhere({
    required String collection,
    required String field,
    required String uid,
    required Map<String, Object?> payload,
  }) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .where(field, isEqualTo: uid)
          .get();
      for (final doc in snapshot.docs) {
        await doc.reference.set(payload, SetOptions(merge: true));
      }
    } catch (e, st) {
      debugPrint('update $collection name refs failed: $e\n$st');
    }
  }

  @override
  Future<void> purgeLearnerCloudPresence(String learnerFirebaseUid) async {
    final uid = learnerFirebaseUid.trim();
    if (!isAvailable || uid.isEmpty) return;
    final db = FirebaseFirestore.instance;

    Future<void> deleteWhere(
      String collection,
      String field,
    ) async {
      try {
        final snapshot = await db
            .collection(collection)
            .where(field, isEqualTo: uid)
            .get();
        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
      } catch (e, st) {
        debugPrint('purge $collection failed: $e\n$st');
      }
    }

    await deleteWhere(linkCollectionName, 'learnerFirebaseUid');
    await deleteWhere(enrollmentCollectionName, 'learnerFirebaseUid');
    await deleteWhere(joinRequestCollectionName, 'learnerFirebaseUid');
    await deleteWhere(activityCollectionName, 'learnerFirebaseUid');
    try {
      await db.collection(userProfileCollectionName).doc(uid).delete();
    } catch (e, st) {
      debugPrint('purge user_profiles failed: $e\n$st');
    }
    try {
      await db.collection(learnerProfileCollectionName).doc(uid).delete();
    } catch (e, st) {
      debugPrint('purge learner_profiles failed: $e\n$st');
    }
  }

  @override
  Future<RemoteUserProfile?> getUserProfile(String firebaseUid) async {
    if (!isAvailable || firebaseUid.trim().isEmpty) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection(userProfileCollectionName)
          .doc(firebaseUid.trim())
          .get();
      if (!doc.exists) return null;
      return _userProfileFromData(firebaseUid.trim(), doc.data());
    } catch (e, st) {
      debugPrint('getUserProfile failed: $e\n$st');
      return null;
    }
  }

  RemoteUserProfile? _userProfileFromData(
    String firebaseUid,
    Map<String, dynamic>? data,
  ) {
    if (data == null) return null;
    return RemoteUserProfile(
      firebaseUid: firebaseUid,
      email: (data['email'] as String?) ?? '',
      fullName: (data['fullName'] as String?) ?? '',
      role: (data['role'] as String?) ?? 'learner',
      firstName: data['firstName'] as String?,
      themeKey: data['themeKey'] as String?,
      profileCode: data['profileCode'] as String?,
      language: data['language'] as String?,
      ttsSpeed: (data['ttsSpeed'] as num?)?.toDouble(),
      address: data['address'] as String?,
      age: (data['age'] as num?)?.toInt(),
      gradeLevel: data['gradeLevel'] as String?,
      birthdate: data['birthdate'] as String?,
      lastName: data['lastName'] as String?,
    );
  }

  @override
  Stream<RemoteUserProfile> watchUserProfile(String firebaseUid) {
    if (!isAvailable || firebaseUid.trim().isEmpty) {
      return const Stream.empty();
    }
    final uid = firebaseUid.trim();
    return FirebaseFirestore.instance
        .collection(userProfileCollectionName)
        .doc(uid)
        .snapshots()
        .map((doc) => _userProfileFromData(uid, doc.data()))
        .where((profile) => profile != null)
        .cast<RemoteUserProfile>();
  }

  @override
  Future<void> upsertLearnerEmergencyContacts({
    required int learnerUserId,
    required String learnerName,
    required String learnerFirebaseUid,
    required List<String> contacts,
    String? profileCode,
  }) async {
    if (!isAvailable || learnerFirebaseUid.trim().isEmpty) return;
    final payload = <String, Object?>{
      'learnerUserId': learnerUserId,
      'learnerName': learnerName,
      'learnerFirebaseUid': learnerFirebaseUid.trim(),
      'emergencyContacts': contacts,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (profileCode != null && profileCode.trim().isNotEmpty) {
      payload['profileCode'] = AppRepository.normalizeProfileCode(profileCode);
    }
    await FirebaseFirestore.instance
        .collection(learnerProfileCollectionName)
        .doc(learnerFirebaseUid.trim())
        .set(payload, SetOptions(merge: true));
  }

  @override
  Future<void> upsertLearnerCategories({
    required String learnerFirebaseUid,
    required List<RemoteLearnerCategory> categories,
  }) async {
    if (!isAvailable || learnerFirebaseUid.trim().isEmpty) return;
    await FirebaseFirestore.instance
        .collection(learnerProfileCollectionName)
        .doc(learnerFirebaseUid.trim())
        .set(
          {
            'learnerFirebaseUid': learnerFirebaseUid.trim(),
            'categories': categories.map((c) => c.toFirestoreMap()).toList(),
            'categoriesUpdatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
  }

  @override
  Future<List<RemoteLearnerCategory>> getLearnerCategories(
    String learnerFirebaseUid,
  ) async {
    if (!isAvailable || learnerFirebaseUid.trim().isEmpty) return const [];
    try {
      final doc = await FirebaseFirestore.instance
          .collection(learnerProfileCollectionName)
          .doc(learnerFirebaseUid.trim())
          .get();
      if (!doc.exists) return const [];
      final raw = doc.data()?['categories'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => RemoteLearnerCategory.fromMap(
                Map<String, dynamic>.from(e),
              ))
          .where((c) => c.key.trim().isNotEmpty)
          .toList();
    } catch (e, st) {
      debugPrint('getLearnerCategories failed: $e\n$st');
      return const [];
    }
  }

  @override
  Future<void> upsertLearnerCustomPhrases({
    required String learnerFirebaseUid,
    required List<RemoteLearnerCustomPhrase> phrases,
  }) async {
    if (!isAvailable || learnerFirebaseUid.trim().isEmpty) return;
    await FirebaseFirestore.instance
        .collection(learnerProfileCollectionName)
        .doc(learnerFirebaseUid.trim())
        .set(
          {
            'learnerFirebaseUid': learnerFirebaseUid.trim(),
            'customPhrases': phrases.map((p) => p.toFirestoreMap()).toList(),
            'customPhrasesUpdatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
  }

  @override
  Future<List<RemoteLearnerCustomPhrase>> getLearnerCustomPhrases(
    String learnerFirebaseUid,
  ) async {
    if (!isAvailable || learnerFirebaseUid.trim().isEmpty) return const [];
    try {
      final doc = await FirebaseFirestore.instance
          .collection(learnerProfileCollectionName)
          .doc(learnerFirebaseUid.trim())
          .get();
      if (!doc.exists) return const [];
      final raw = doc.data()?['customPhrases'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map(
            (e) => RemoteLearnerCustomPhrase.fromMap(
              Map<String, dynamic>.from(e),
            ),
          )
          .where((p) => p.phraseText.trim().isNotEmpty)
          .toList();
    } catch (e, st) {
      debugPrint('getLearnerCustomPhrases failed: $e\n$st');
      return const [];
    }
  }

  @override
  Future<void> upsertLearnerFavorites({
    required String learnerFirebaseUid,
    required List<RemoteLearnerFavorite> favorites,
  }) async {
    if (!isAvailable || learnerFirebaseUid.trim().isEmpty) return;
    await FirebaseFirestore.instance
        .collection(learnerProfileCollectionName)
        .doc(learnerFirebaseUid.trim())
        .set(
          {
            'learnerFirebaseUid': learnerFirebaseUid.trim(),
            'favorites': favorites.map((f) => f.toFirestoreMap()).toList(),
            'favoritesUpdatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
  }

  @override
  Future<List<RemoteLearnerFavorite>> getLearnerFavorites(
    String learnerFirebaseUid,
  ) async {
    if (!isAvailable || learnerFirebaseUid.trim().isEmpty) return const [];
    try {
      final doc = await FirebaseFirestore.instance
          .collection(learnerProfileCollectionName)
          .doc(learnerFirebaseUid.trim())
          .get();
      if (!doc.exists) return const [];
      final raw = doc.data()?['favorites'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map(
            (e) => RemoteLearnerFavorite.fromMap(
              Map<String, dynamic>.from(e),
            ),
          )
          .where((f) => f.phraseText.trim().isNotEmpty)
          .toList();
    } catch (e, st) {
      debugPrint('getLearnerFavorites failed: $e\n$st');
      return const [];
    }
  }

  @override
  Future<void> upsertLearnerSpeakHistory({
    required String learnerFirebaseUid,
    required List<RemoteLearnerSpeakHistory> history,
  }) async {
    if (!isAvailable || learnerFirebaseUid.trim().isEmpty) return;
    await FirebaseFirestore.instance
        .collection(learnerProfileCollectionName)
        .doc(learnerFirebaseUid.trim())
        .set(
          {
            'learnerFirebaseUid': learnerFirebaseUid.trim(),
            'speakHistory': history.map((h) => h.toFirestoreMap()).toList(),
            'speakHistoryUpdatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
  }

  @override
  Future<List<RemoteLearnerSpeakHistory>> getLearnerSpeakHistory(
    String learnerFirebaseUid,
  ) async {
    if (!isAvailable || learnerFirebaseUid.trim().isEmpty) return const [];
    try {
      final doc = await FirebaseFirestore.instance
          .collection(learnerProfileCollectionName)
          .doc(learnerFirebaseUid.trim())
          .get();
      if (!doc.exists) return const [];
      final raw = doc.data()?['speakHistory'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map(
            (e) => RemoteLearnerSpeakHistory.fromMap(
              Map<String, dynamic>.from(e),
            ),
          )
          .where((h) => h.phraseText.trim().isNotEmpty)
          .toList();
    } catch (e, st) {
      debugPrint('getLearnerSpeakHistory failed: $e\n$st');
      return const [];
    }
  }

  @override
  Future<List<String>> getLearnerEmergencyContacts(
    String learnerFirebaseUid,
  ) async {
    if (!isAvailable || learnerFirebaseUid.trim().isEmpty) return const [];
    try {
      final doc = await FirebaseFirestore.instance
          .collection(learnerProfileCollectionName)
          .doc(learnerFirebaseUid.trim())
          .get();
      if (!doc.exists) return const [];
      final contacts = doc.data()?['emergencyContacts'];
      if (contacts is! List) return const [];
      return AppRepository.normalizeEmergencyContacts(
        contacts.whereType<String>().toList(),
      );
    } catch (e, st) {
      debugPrint('getLearnerEmergencyContacts failed: $e\n$st');
      return const [];
    }
  }

  @override
  Stream<RemoteLearnerPersonalBoardSnapshot> watchLearnerPersonalBoard(
    String learnerFirebaseUid,
  ) {
    if (!isAvailable || learnerFirebaseUid.trim().isEmpty) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection(learnerProfileCollectionName)
        .doc(learnerFirebaseUid.trim())
        .snapshots()
        .map((doc) => _personalBoardFromData(doc.data() ?? {}));
  }

  RemoteLearnerPersonalBoardSnapshot _personalBoardFromData(
    Map<String, dynamic> data,
  ) {
    final categories = <RemoteLearnerCategory>[];
    final categoriesRaw = data['categories'];
    if (categoriesRaw is List) {
      for (final raw in categoriesRaw) {
        if (raw is! Map) continue;
        final category = RemoteLearnerCategory.fromMap(
          Map<String, dynamic>.from(raw),
        );
        if (category.key.trim().isNotEmpty) {
          categories.add(category);
        }
      }
    }

    final customPhrases = <RemoteLearnerCustomPhrase>[];
    final phrasesRaw = data['customPhrases'];
    if (phrasesRaw is List) {
      for (final raw in phrasesRaw) {
        if (raw is! Map) continue;
        final phrase = RemoteLearnerCustomPhrase.fromMap(
          Map<String, dynamic>.from(raw),
        );
        if (phrase.phraseText.trim().isNotEmpty) {
          customPhrases.add(phrase);
        }
      }
    }

    final favorites = <RemoteLearnerFavorite>[];
    final favoritesRaw = data['favorites'];
    if (favoritesRaw is List) {
      for (final raw in favoritesRaw) {
        if (raw is! Map) continue;
        final favorite = RemoteLearnerFavorite.fromMap(
          Map<String, dynamic>.from(raw),
        );
        if (favorite.phraseText.trim().isNotEmpty) {
          favorites.add(favorite);
        }
      }
    }

    final speakHistory = <RemoteLearnerSpeakHistory>[];
    final historyRaw = data['speakHistory'];
    if (historyRaw is List) {
      for (final raw in historyRaw) {
        if (raw is! Map) continue;
        final entry = RemoteLearnerSpeakHistory.fromMap(
          Map<String, dynamic>.from(raw),
        );
        if (entry.phraseText.trim().isNotEmpty) {
          speakHistory.add(entry);
        }
      }
    }

    return RemoteLearnerPersonalBoardSnapshot(
      categories: categories,
      customPhrases: customPhrases,
      favorites: favorites,
      speakHistory: speakHistory,
    );
  }

  @override
  Future<void> markParentNotificationRead(String remoteId) async {
    if (!isAvailable || remoteId.trim().isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(remoteId.trim())
          .update({'isRead': true});
    } catch (e, st) {
      debugPrint('markParentNotificationRead failed: $e\n$st');
    }
  }

  @override
  Stream<List<RemoteClassEnrollment>> watchClassEnrollmentsForLearner(
    String learnerFirebaseUid,
  ) {
    if (!isAvailable || learnerFirebaseUid.trim().isEmpty) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection(enrollmentCollectionName)
        .where('learnerFirebaseUid', isEqualTo: learnerFirebaseUid.trim())
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_enrollmentFromDocument).toList());
  }

  @override
  Stream<List<RemoteClassEnrollment>> watchClassEnrollmentsForTeacher(
    String teacherFirebaseUid,
  ) {
    if (!isAvailable || teacherFirebaseUid.trim().isEmpty) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection(enrollmentCollectionName)
        .where('teacherFirebaseUid', isEqualTo: teacherFirebaseUid.trim())
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_enrollmentFromDocument).toList());
  }

  @override
  Stream<List<RemoteParentChildLink>> watchParentChildLinks(
    String parentFirebaseUid,
  ) {
    if (!isAvailable || parentFirebaseUid.trim().isEmpty) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection(linkCollectionName)
        .where('parentFirebaseUid', isEqualTo: parentFirebaseUid.trim())
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(_parentChildLinkFromDocument).toList(),
        );
  }

  @override
  Stream<List<RemoteTeacherClass>> watchTeacherClassesForTeacher(
    String teacherFirebaseUid,
  ) {
    if (!isAvailable || teacherFirebaseUid.trim().isEmpty) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection(teacherClassCollectionName)
        .where('teacherFirebaseUid', isEqualTo: teacherFirebaseUid.trim())
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_teacherClassFromDocument).toList());
  }

  @override
  Stream<List<RemoteParentNotification>> watchParentNotifications({
    required int parentUserId,
    required String parentFirebaseUid,
  }) {
    if (!isAvailable || parentFirebaseUid.trim().isEmpty) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection(collectionName)
        .where('parentFirebaseUid', isEqualTo: parentFirebaseUid)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => _fromDocument(doc, parentUserId))
          .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  RemoteParentNotification _fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    int parentUserId,
  ) {
    final data = doc.data();
    return RemoteParentNotification(
      remoteId: doc.id,
      parentUserId: parentUserId,
      learnerUserId: data['learnerUserId'] as int?,
      childName: (data['childName'] as String?) ?? '',
      title: (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      alertType: (data['alertType'] as String?) ?? 'teacherAlert',
      createdAt: _readTimestamp(data['createdAt']),
      isRead: data['isRead'] as bool? ?? false,
    );
  }

  RemoteTeacherAlert _teacherAlertFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return RemoteTeacherAlert(
      remoteId: doc.id,
      teacherUserId: data['teacherUserId'] as int? ?? 0,
      parentUserId: data['parentUserId'] as int? ?? 0,
      localNotificationId: data['localNotificationId'] as int? ?? 0,
      learnerUserId: data['learnerUserId'] as int? ?? 0,
      childName: (data['childName'] as String?) ?? '',
      classId: data['classId'] as int? ?? 0,
      className: (data['className'] as String?) ?? '',
      alertType: (data['alertType'] as String?) ?? 'teacherAlert',
      title: (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      createdAt: _readTimestamp(data['createdAt']),
    );
  }

  @override
  Future<List<RemoteTeacherAlert>> getTeacherAlerts({
    required int teacherUserId,
    required String teacherFirebaseUid,
  }) async {
    if (!isAvailable ||
        teacherUserId <= 0 ||
        teacherFirebaseUid.trim().isEmpty) {
      return const [];
    }
    final snapshot = await FirebaseFirestore.instance
        .collection(collectionName)
        .where('teacherFirebaseUid', isEqualTo: teacherFirebaseUid.trim())
        .get();
    final items = snapshot.docs.map(_teacherAlertFromDocument).toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  @override
  Stream<List<RemoteTeacherAlert>> watchTeacherAlerts({
    required int teacherUserId,
    required String teacherFirebaseUid,
  }) {
    if (!isAvailable ||
        teacherUserId <= 0 ||
        teacherFirebaseUid.trim().isEmpty) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection(collectionName)
        .where('teacherFirebaseUid', isEqualTo: teacherFirebaseUid.trim())
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs.map(_teacherAlertFromDocument).toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  @override
  Future<void> addTeacherDeletedClassCode({
    required String teacherFirebaseUid,
    required String classCode,
  }) async {
    if (!isAvailable) return;
    final uid = teacherFirebaseUid.trim();
    final code = AppRepository.normalizeClassCode(classCode);
    if (uid.isEmpty || !AppRepository.isValidClassCodeFormat(code)) return;
    try {
      await FirebaseFirestore.instance
          .collection(userProfileCollectionName)
          .doc(uid)
          .set(
        {
          'deletedTeacherClassCodes': FieldValue.arrayUnion([code]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e, st) {
      debugPrint('addTeacherDeletedClassCode failed: $e\n$st');
    }
  }

  @override
  Future<List<String>> getTeacherDeletedClassCodes(
    String teacherFirebaseUid,
  ) async {
    if (!isAvailable) return const [];
    final uid = teacherFirebaseUid.trim();
    if (uid.isEmpty) return const [];
    try {
      final doc = await FirebaseFirestore.instance
          .collection(userProfileCollectionName)
          .doc(uid)
          .get();
      final raw = doc.data()?['deletedTeacherClassCodes'];
      if (raw is! List) return const [];
      return raw
          .whereType<String>()
          .map(AppRepository.normalizeClassCode)
          .where(AppRepository.isValidClassCodeFormat)
          .toSet()
          .toList();
    } catch (e, st) {
      debugPrint('getTeacherDeletedClassCodes failed: $e\n$st');
      return const [];
    }
  }

  DateTime _readTimestamp(Object? raw) {
    if (raw is Timestamp) return raw.toDate().toLocal();
    if (raw is String) return DateTime.parse(raw).toLocal();
    return DateTime.now();
  }

  int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  RemoteClassJoinRequest _joinRequestFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return RemoteClassJoinRequest(
      classId: _readInt(data['classId']),
      classCode: (data['classCode'] as String?) ?? '',
      className: (data['className'] as String?) ?? '',
      teacherFirebaseUid: (data['teacherFirebaseUid'] as String?) ?? '',
      teacherUserId: _readInt(data['teacherUserId']),
      learnerUserId: _readInt(data['learnerUserId']),
      learnerName: (data['learnerName'] as String?) ?? '',
      learnerFirebaseUid: (data['learnerFirebaseUid'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'pending',
      requestedAt: _readTimestamp(data['requestedAt']),
      respondedAt: data['respondedAt'] == null
          ? null
          : _readTimestamp(data['respondedAt']),
      remoteId: doc.id,
    );
  }

  RemoteClassEnrollment _enrollmentFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return RemoteClassEnrollment(
      classId: data['classId'] as int? ?? 0,
      classCode: (data['classCode'] as String?) ?? '',
      className: (data['className'] as String?) ?? '',
      learnerUserId: data['learnerUserId'] as int? ?? 0,
      learnerName: (data['learnerName'] as String?) ?? '',
      learnerFirebaseUid: (data['learnerFirebaseUid'] as String?) ?? '',
      enrolledAt: _readTimestamp(data['enrolledAt']),
      teacherName: data['teacherName'] as String?,
    );
  }

  RemoteTeacherClass _teacherClassFromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return RemoteTeacherClass(
      classCode: (data['classCode'] as String?) ?? doc.id,
      className: (data['className'] as String?) ?? '',
      teacherFirebaseUid: (data['teacherFirebaseUid'] as String?) ?? '',
      teacherUserId: data['teacherUserId'] as int? ?? 0,
      createdAt: _readTimestamp(data['createdAt']),
      teacherName: data['teacherName'] as String?,
    );
  }

  RemoteLearnerProfile _learnerProfileFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return RemoteLearnerProfile(
      learnerFirebaseUid:
          (data['learnerFirebaseUid'] as String?) ?? doc.id,
      learnerName: (data['learnerName'] as String?) ?? '',
      profileCode: (data['profileCode'] as String?) ?? '',
      learnerUserId: data['learnerUserId'] as int? ?? 0,
    );
  }

  RemoteParentChildLink _parentChildLinkFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return RemoteParentChildLink(
      parentFirebaseUid: (data['parentFirebaseUid'] as String?) ?? '',
      learnerFirebaseUid: (data['learnerFirebaseUid'] as String?) ?? '',
      parentUserId: data['parentUserId'] as int? ?? 0,
      learnerUserId: data['learnerUserId'] as int? ?? 0,
      learnerName: (data['learnerName'] as String?) ?? '',
      learnerProfileCode: (data['learnerProfileCode'] as String?) ?? '',
    );
  }

  @override
  Future<void> dispose() async {}
}
