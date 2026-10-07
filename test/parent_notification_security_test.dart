import 'package:flutter_application_1/data/database/database_helper.dart';
import 'package:flutter_application_1/data/repositories/app_repository.dart';
import 'package:flutter_application_1/services/cloud_notification_backend.dart';
import 'package:flutter_application_1/services/notification_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _ContactCloud extends UnconfiguredCloudNotificationBackend {
  List<String> contacts = [];
  bool fails = false;
  @override
  bool get isAvailable => true;
  @override
  Future<List<String>> getLearnerEmergencyContacts(String uid) async {
    if (fails) throw StateError('Authorization unavailable');
    return contacts;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late AppRepository repo;
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(
      'CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT, full_name TEXT, role TEXT, firebase_uid TEXT, settings_json TEXT)',
    );
    await db.execute(
      'CREATE TABLE parent_children (parent_user_id INTEGER, learner_user_id INTEGER, linked_at INTEGER)',
    );
    await db.execute(
      'CREATE TABLE parent_notifications (id INTEGER PRIMARY KEY AUTOINCREMENT, parent_user_id INTEGER, learner_user_id INTEGER, child_name TEXT, alert_type TEXT, title TEXT, body TEXT, created_at INTEGER, is_read INTEGER, remote_id TEXT)',
    );
    for (final id in [42, 99]) {
      await db.insert('users', {
        'id': id,
        'email': '$id@example.test',
        'full_name': 'Learner $id',
        'role': 'learner',
        'firebase_uid': 'learner-$id',
      });
    }
    await db.insert('users', {
      'id': 100,
      'email': 'local@example.test',
      'full_name': 'Local only',
      'role': 'learner',
    });
    await db.insert('parent_children', {
      'parent_user_id': 1,
      'learner_user_id': 42,
      'linked_at': 1,
    });
    repo = AppRepository(DatabaseHelper.withDatabase(db));
  });
  tearDown(() => db.close());

  test('teacher SMS uses fresh contacts and never merges a removed recipient from cache', () async {
    final cloud = _ContactCloud()..contacts = ['09987654321'];
    final sync = NotificationSyncService(repository: repo, cloudBackend: cloud);
    final contacts = await sync.resolveEmergencyContacts(learnerUserId: 42, localContacts: ['09123456789'], learnerFirebaseUid: 'learner-42');
    expect(contacts, AppRepository.normalizeEmergencyContacts(['09987654321']));
    cloud.contacts = [];
    expect(await sync.resolveEmergencyContacts(learnerUserId: 42, localContacts: contacts, learnerFirebaseUid: 'learner-42'), isEmpty);
    expect(await repo.getEmergencyContactsForLearner(42), isEmpty);
    cloud.fails = true;
    expect(await sync.resolveEmergencyContacts(learnerUserId: 42, localContacts: contacts, learnerFirebaseUid: 'learner-42'), isEmpty);
  });

  RemoteParentNotification item({
    String remoteId = 'alert',
    String? uid = 'learner-42',
    int localIdFromTeacher = 99,
    int parentId = 1,
  }) => RemoteParentNotification(
    remoteId: remoteId,
    parentUserId: parentId,
    learnerUserId: localIdFromTeacher,
    learnerFirebaseUid: uid,
    childName: 'Learner',
    title: 'Alert',
    body: 'Protected text',
    alertType: 'teacherAlert',
    createdAt: DateTime(2026, 10, 7),
    isRead: false,
  );
  test(
    'remote notifications resolve the cloud learner UID rather than teacher-local IDs',
    () async {
      await repo.upsertRemoteParentNotifications(
        parentUserId: 1,
        items: [item()],
      );
      final rows = await db.query('parent_notifications');
      expect(rows.single['learner_user_id'], 42);
      await repo.upsertRemoteParentNotifications(
        parentUserId: 1,
        items: [item(localIdFromTeacher: 200)],
      );
      expect(await db.query('parent_notifications'), hasLength(1));
    },
  );
  test(
    'unlinked, unknown, missing-UID and other-parent notifications never enter the cache',
    () async {
      await repo.upsertRemoteParentNotifications(
        parentUserId: 1,
        items: [
          item(uid: 'learner-99'),
          item(uid: 'unknown'),
          item(uid: null),
          item(parentId: 2),
        ],
      );
      expect(await db.query('parent_notifications'), isEmpty);
      await repo.upsertRemoteParentNotifications(
        parentUserId: 1,
        items: [item()],
      );
      await db.delete('parent_children');
      await repo.upsertRemoteParentNotifications(
        parentUserId: 1,
        items: [item(remoteId: 'after-revocation')],
      );
      expect(await db.query('parent_notifications'), hasLength(1));
    },
  );
  test(
    'verified snapshots prune both revoked cloud links and local-only legacy links',
    () async {
      await db.insert('parent_children', {
        'parent_user_id': 1,
        'learner_user_id': 99,
        'linked_at': 1,
      });
      await db.insert('parent_children', {
        'parent_user_id': 1,
        'learner_user_id': 100,
        'linked_at': 1,
      });
      await repo.pruneStaleParentChildLinks(
        parentUserId: 1,
        remoteLearnerFirebaseUids: {'learner-42'},
      );
      final rows = await db.query('parent_children');
      expect(rows, hasLength(1));
      expect(rows.single['learner_user_id'], 42);
    },
  );
}
