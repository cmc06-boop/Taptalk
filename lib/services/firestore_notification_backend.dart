import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'cloud_notification_backend.dart';
import 'firebase_service.dart';

/// Firestore-backed notifications for cross-device parent alerts.
class FirestoreNotificationBackend implements CloudNotificationBackend {
  static const String collectionName = 'parent_notifications';
  static const String linkCollectionName = 'parent_child_links';
  static const String enrollmentCollectionName = 'class_enrollments_cloud';
  static const String learnerProfileCollectionName = 'learner_profiles';

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
        .set({
      'parentUserId': parentUserId,
      'learnerUserId': learnerUserId,
      'parentFirebaseUid': parentFirebaseUid.trim(),
      'learnerFirebaseUid': learnerFirebaseUid.trim(),
      'linkedAt': FieldValue.serverTimestamp(),
    });
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
  Future<void> upsertLearnerEmergencyContacts({
    required int learnerUserId,
    required String learnerName,
    required String learnerFirebaseUid,
    required List<String> contacts,
  }) async {
    if (!isAvailable || learnerFirebaseUid.trim().isEmpty) return;
    await FirebaseFirestore.instance
        .collection(learnerProfileCollectionName)
        .doc(learnerFirebaseUid.trim())
        .set({
      'learnerUserId': learnerUserId,
      'learnerName': learnerName,
      'learnerFirebaseUid': learnerFirebaseUid.trim(),
      'emergencyContacts': contacts,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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

  @override
  Future<void> dispose() async {}
}
