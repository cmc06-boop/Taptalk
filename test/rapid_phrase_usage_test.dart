import 'package:flutter_application_1/core/utils/negative_phrases.dart';
import 'package:flutter_application_1/data/database/database_helper.dart';
import 'package:flutter_application_1/data/repositories/app_repository.dart';
import 'package:flutter_application_1/services/cloud_notification_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late AppRepository repo;
  final time = DateTime(2026, 10, 7, 10);
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    // Start from the previous schema to exercise the upgrade too.
    await db.execute(
      'CREATE TABLE history (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'user_id INTEGER NOT NULL, phrase_text TEXT NOT NULL, category_key TEXT NOT NULL, '
      'created_at INTEGER NOT NULL, class_name TEXT, lesson_title TEXT, remote_sync_key TEXT)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX idx_history_remote_sync_key ON history(user_id, remote_sync_key) WHERE remote_sync_key IS NOT NULL',
    );
    await DatabaseHelper.ensureHistoryEventIdentity(db);
    repo = AppRepository(DatabaseHelper.withDatabase(db));
  });
  tearDown(() => db.close());

  Future<int> count(int userId) async => (await repo.getPhraseUsageStats(
    learnerUserId: userId,
    rangeStart: DateTime(2026, 10, 7),
    rangeEnd: DateTime(2026, 10, 8),
  )).fold<int>(0, (sum, stat) => sum + stat.count);

  test(
    'ten parallel taps at the same millisecond remain ten after reads and cleanup',
    () async {
      await Future.wait(
        List.generate(
          10,
          (_) => repo.addHistory(
            userId: 1,
            text: 'Help',
            categoryKey: 'needs',
            createdAt: time,
          ),
        ),
      );
      expect(await count(1), 10);
      expect(await repo.getHistory(1), hasLength(10));
      final pending = await repo.getUnsyncedHistory(1);
      expect(pending.map((e) => e.eventId).toSet(), hasLength(10));
      final exported = await repo.getHistoryForCloudSync(1);
      expect(exported, hasLength(10));
      await repo.dedupeMonitoringHistory(1);
      expect(await count(1), 10);
    },
  );

  test(
    'recording the same identified action twice only inserts once',
    () async {
      final ids = await Future.wait(
        List.generate(
          2,
          (_) => repo.addHistory(
            userId: 1,
            text: 'Help',
            categoryKey: 'needs',
            createdAt: time,
            eventId: 'same-action',
          ),
        ),
      );
      expect(ids.whereType<int>(), hasLength(1));
      expect(await count(1), 1);
    },
  );

  test(
    'rapid taps survive export, wire serialization and both cloud import paths',
    () async {
      await Future.wait(
        List.generate(
          10,
          (i) => repo.addHistory(
            userId: 1,
            text: i.isEven ? 'Help' : 'Tulong',
            categoryKey: i.isEven ? 'needs' : 'health_safety',
            createdAt: time,
          ),
        ),
      );
      final snapshot = (await repo.getHistoryForCloudSync(1))
          .map(
            (e) => RemoteLearnerSpeakHistory.fromMap(
              Map<String, dynamic>.from(e.toFirestoreMap()),
            ),
          )
          .toList();
      final activities = snapshot
          .map(
            (e) => RemoteLearnerActivity(
              phraseText: e.phraseText,
              categoryKey: e.categoryKey,
              createdAt: e.createdAt,
              eventId: e.eventId,
            ),
          )
          .toList();
      await Future.wait([
        repo.mergeRemoteLearnerSpeakHistory(
          learnerUserId: 2,
          history: snapshot,
        ),
        repo.mergeRemoteLearnerActivities(
          learnerUserId: 2,
          activities: activities,
        ),
      ]);
      await repo.mergeRemoteLearnerActivities(
        learnerUserId: 2,
        activities: activities,
      );
      expect(await count(2), 10);
      expect(await count(1), 10);
      final stats = await repo.getPhraseUsageStats(
        learnerUserId: 2,
        rangeStart: DateTime(2026, 10, 7),
        rangeEnd: DateTime(2026, 10, 8),
      );
      expect(NegativePhrases.dailyTotals(stats), {'help': 10});
      final cloud = AppRepository.aggregatePhraseUsageStatsFromActivities(
        activities: [...activities, ...activities],
        rangeStart: DateTime(2026, 10, 7),
        rangeEnd: DateTime(2026, 10, 8),
      );
      expect(NegativePhrases.dailyTotals(cloud), {'help': 10});
      expect(
        AppRepository.mergeSpeakHistoryForCloudExport(
          local: snapshot,
          remote: snapshot,
        ),
        hasLength(10),
      );
    },
  );

  test(
    'legacy events 100ms apart survive while an identical replay stays deduplicated',
    () async {
      final events = List.generate(
        10,
        (i) => RemoteLearnerActivity(
          phraseText: 'Help',
          categoryKey: 'needs',
          createdAt: time.add(Duration(milliseconds: i * 100)),
        ),
      );
      await repo.mergeRemoteLearnerActivities(
        learnerUserId: 1,
        activities: [...events, ...events],
      );
      expect(await count(1), 10);
      await repo.dedupeMonitoringHistory(1);
      expect(await count(1), 10);
    },
  );

  test(
    'an identified snapshot upgrades a legacy copy without merging a second tap',
    () async {
      await repo.mergeRemoteLearnerActivities(
        learnerUserId: 1,
        activities: [
          RemoteLearnerActivity(
            phraseText: 'Help',
            categoryKey: 'needs',
            createdAt: time,
          ),
        ],
      );
      final modern = [
        for (final id in ['tap-a', 'tap-b'])
          RemoteLearnerActivity(
            phraseText: 'Help',
            categoryKey: 'needs',
            createdAt: time,
            eventId: id,
          ),
      ];
      await repo.mergeRemoteLearnerActivities(
        learnerUserId: 1,
        activities: modern,
      );
      expect(await count(1), 2);
      await repo.mergeRemoteLearnerActivities(
        learnerUserId: 1,
        activities: modern,
      );
      expect(await count(1), 2);
    },
  );

  test(
    'live and retry uploads carry the same ID while separate taps get different keys',
    () {
      final event = LearnerActivityCloudEvent(
        learnerFirebaseUid: 'learner',
        phraseText: 'Help',
        categoryKey: 'needs',
        createdAt: time,
        eventId: 'tap-a',
      );
      expect(event.toFirestoreMap()['eventId'], 'tap-a');
      final first = AppRepository.remoteActivitySyncKey(
        createdAt: time,
        phraseText: 'Help',
        categoryKey: 'needs',
        eventId: 'tap-a',
      );
      final second = AppRepository.remoteActivitySyncKey(
        createdAt: time,
        phraseText: 'Help',
        categoryKey: 'needs',
        eventId: 'tap-b',
      );
      expect(first, isNot(second));
      expect(
        first,
        AppRepository.remoteActivitySyncKey(
          createdAt: time,
          phraseText: 'Help',
          categoryKey: 'needs',
          eventId: 'tap-a',
        ),
      );
    },
  );

  test(
    'identity migration is safe to rerun and preserves legacy records',
    () async {
      await db.insert('history', {
        'user_id': 1,
        'phrase_text': 'Help',
        'category_key': 'needs',
        'created_at': time.millisecondsSinceEpoch,
      });
      await DatabaseHelper.ensureHistoryEventIdentity(db);
      expect(await count(1), 1);
    },
  );
}
