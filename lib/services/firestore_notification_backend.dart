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
  static const String teacherClassCollectionName = 'teacher_classes_cloud';
  static const String learnerProfileCollectionName = 'learner_profiles';
  static const String userProfileCollectionName = 'user_profiles';
  static const String activityCollectionName = 'learner_activity';

  @override
  bool get isAvailable => FirebaseService.instance.isAvailable;

  @override
  Future<void> initialize() async {
    await FirebaseService.instance.initialize();
  }

  @override
  Future<void> publishTeacherAlert(TeacherAlertCloudEvent event) async {
    if (!isAvailable) return;
    if (event.parentFirebaseUid.trim().isEmpty) {
      debugPrint('Skipping cloud alert: parent has no Firebase account linked.');
      return;
    }

    final payload = event.toFirestoreMap()
      ..['parentFirebaseUid'] = event.parentFirebaseUid
      ..['createdAt'] = Timestamp.fromDate(event.createdAt.toUtc());

    await FirebaseFirestore.instance.collection(collectionName).add(payload);
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
    final docId = '${event.classCode.trim()}_${event.learnerFirebaseUid.trim()}';
    final payload = event.toFirestoreMap()
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
    final docId = '${classCode.trim()}_${learnerFirebaseUid.trim()}';
    await FirebaseFirestore.instance
        .collection(enrollmentCollectionName)
        .doc(docId)
        .delete();
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
      final snapshot = await FirebaseFirestore.instance
          .collection(activityCollectionName)
          .where('learnerFirebaseUid', isEqualTo: learnerFirebaseUid.trim())
          .where('createdAt',
              isGreaterThanOrEqualTo:
                  Timestamp.fromDate(rangeStart.toUtc()))
          .where('createdAt',
              isLessThan: Timestamp.fromDate(rangeEnd.toUtc()))
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return RemoteLearnerActivity(
          phraseText: (data['phraseText'] as String?) ?? '',
          categoryKey: (data['categoryKey'] as String?) ?? '',
          createdAt: _readTimestamp(data['createdAt']),
          className: data['className'] as String?,
          lessonTitle: data['lessonTitle'] as String?,
        );
      }).toList();
    } catch (e, st) {
      debugPrint('getLearnerActivities failed: $e\n$st');
      return const [];
    }
  }

  @override
  Future<void> upsertTeacherClass(TeacherClassCloudEvent event) async {
    if (!isAvailable ||
        event.classCode.trim().isEmpty ||
        event.teacherFirebaseUid.trim().isEmpty) {
      return;
    }
    final docId = AppRepository.normalizeClassCode(event.classCode);
    final payload = event.toFirestoreMap()
      ..['createdAt'] = Timestamp.fromDate(event.createdAt.toUtc());
    await FirebaseFirestore.instance
        .collection(teacherClassCollectionName)
        .doc(docId)
        .set(payload);
  }

  @override
  Future<void> removeTeacherClass({required String classCode}) async {
    if (!isAvailable || classCode.trim().isEmpty) return;
    final docId = AppRepository.normalizeClassCode(classCode);
    await FirebaseFirestore.instance
        .collection(teacherClassCollectionName)
        .doc(docId)
        .delete();
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
      if (!doc.exists) return null;
      return _teacherClassFromDocument(doc);
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
      if (snapshot.docs.isEmpty) return null;
      return _learnerProfileFromDocument(snapshot.docs.first);
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
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(linkCollectionName)
          .where('parentFirebaseUid', isEqualTo: parentFirebaseUid.trim())
          .get();
      return snapshot.docs.map(_parentChildLinkFromDocument).toList();
    } catch (e, st) {
      debugPrint('getParentChildLinksForParent failed: $e\n$st');
      return const [];
    }
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
    if (profile.themeKey != null && profile.themeKey!.trim().isNotEmpty) {
      payload['themeKey'] = profile.themeKey!.trim();
    }
    if (profile.profileCode != null && profile.profileCode!.trim().isNotEmpty) {
      payload['profileCode'] = AppRepository.normalizeProfileCode(
        profile.profileCode!,
      );
    }
    await FirebaseFirestore.instance
        .collection(userProfileCollectionName)
        .doc(profile.firebaseUid.trim())
        .set(payload, SetOptions(merge: true));
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
      final data = doc.data();
      if (data == null) return null;
      return RemoteUserProfile(
        firebaseUid: firebaseUid.trim(),
        email: (data['email'] as String?) ?? '',
        fullName: (data['fullName'] as String?) ?? '',
        role: (data['role'] as String?) ?? 'learner',
        themeKey: data['themeKey'] as String?,
        profileCode: data['profileCode'] as String?,
      );
    } catch (e, st) {
      debugPrint('getUserProfile failed: $e\n$st');
      return null;
    }
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
      return contacts
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .take(2)
          .toList();
    } catch (e, st) {
      debugPrint('getLearnerEmergencyContacts failed: $e\n$st');
      return const [];
    }
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

  DateTime _readTimestamp(Object? raw) {
    if (raw is Timestamp) return raw.toDate().toLocal();
    if (raw is String) return DateTime.parse(raw).toLocal();
    return DateTime.now();
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
