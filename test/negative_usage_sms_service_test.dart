import 'dart:async';

import 'package:flutter_application_1/core/l10n/app_strings.dart';
import 'package:flutter_application_1/data/database/database_helper.dart';
import 'package:flutter_application_1/data/models/sms_alert_result.dart';
import 'package:flutter_application_1/data/repositories/app_repository.dart';
import 'package:flutter_application_1/services/device_sms_service.dart';
import 'package:flutter_application_1/services/negative_usage_sms_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeSms extends DeviceSmsService {
  final List<String> calls = [];
  final Set<String> failedNumbers = {};
  bool composerOnly = false;
  Completer<void>? gate;

  @override
  Future<SmsAlertResult> sendAutomaticAlert({
    required AppLanguage language,
    required String phoneNumber,
    required String message,
  }) async {
    calls.add(phoneNumber);
    if (gate != null) await gate!.future;
    final failed = failedNumbers.contains(phoneNumber);
    return SmsAlertResult(
      attempted: 1,
      sent: failed ? 0 : 1,
      failed: failed ? 1 : 0,
      errorMessage: failed ? 'No signal' : null,
      openedComposer: composerOnly,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late AppRepository repo;
  late FakeSms sms;
  late NegativeUsageSmsService service;
  late DateTime now;
  final day = DateTime(2026, 10, 7);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await DatabaseHelper.createWarningSmsDeliveriesTable(db);
    repo = AppRepository(DatabaseHelper.withDatabase(db));
    sms = FakeSms();
    now = day.add(const Duration(hours: 10));
    service = NegativeUsageSmsService(
      repository: repo,
      sms: sms,
      now: () => now,
    );
  });
  tearDown(() async => db.close());

  Future<String> send({
    String phrase = 'Help',
    List<String>? contacts,
    DateTime? date,
    bool allowed = true,
    NegativeUsageSmsService? sender,
  }) => (sender ?? service).send(
    teacherUserId: 1,
    learnerUserId: 2,
    phraseKey: phrase,
    dayStart: date ?? day,
    language: AppLanguage.english,
    contacts: contacts ?? ['09171234567'],
    message: 'Test warning',
    canSend: () => allowed,
  );

  test(
    'sends only once across refresh, language change and service restart',
    () async {
      await send(contacts: ['09171234567', '+639171234567']);
      await send(phrase: 'Tulong');
      final restarted = NegativeUsageSmsService(
        repository: AppRepository(DatabaseHelper.withDatabase(db)),
        sms: sms,
        now: () => now,
      );
      await send(sender: restarted);
      expect(sms.calls, ['+639171234567']);
    },
  );

  test(
    'partial failure retries only the failed number after cooldown',
    () async {
      sms.failedNumbers.add('+639181234567');
      const contacts = ['09171234567', '09181234567'];
      final status = await send(contacts: contacts);
      expect(status, contains('1 of 2'));
      expect(status, contains('No signal'));
      await send(contacts: contacts);
      expect(sms.calls, hasLength(2));
      now = now.add(const Duration(minutes: 5));
      sms.failedNumbers.clear();
      expect(await send(contacts: contacts), contains('2 of 2'));
      expect(sms.calls, ['+639171234567', '+639181234567', '+639181234567']);
    },
  );

  test('concurrent evaluations cannot submit the same SMS twice', () async {
    sms.gate = Completer<void>();
    final first = send();
    while (sms.calls.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await send(phrase: 'Tulong');
    expect(sms.calls, hasLength(1));
    sms.gate!.complete();
    await first;
  });

  test('opening a composer does not count as automatic submission', () async {
    sms.composerOnly = true;
    expect(await send(), contains('0 of 1'));
    final rows = await repo.getWarningSmsDeliveries(
      teacherUserId: 1,
      learnerUserId: 2,
      phraseKey: 'help',
      dayStart: day,
    );
    expect(rows.single['status'], 'failed');
  });

  test('next day can generate a new SMS', () async {
    await send();
    now = now.add(const Duration(days: 1));
    await send(date: day.add(const Duration(days: 1)));
    expect(sms.calls, hasLength(2));
  });

  test('invalid contacts and a signed-out teacher do not send', () async {
    await send(contacts: ['invalid']);
    await send(allowed: false);
    expect(sms.calls, isEmpty);
  });

  test(
    'an interrupted submission is not automatically resent after restart',
    () async {
      await repo.claimWarningSms(
        teacherUserId: 1,
        learnerUserId: 2,
        phraseKey: 'help',
        dayStart: day,
        phoneNumber: '+639171234567',
        now: now,
      );
      now = now.add(const Duration(hours: 1));
      expect(await send(), contains('not confirmed'));
      expect(sms.calls, isEmpty);
    },
  );

  test(
    'legacy Filipino warning prevents a second in-app warning in English',
    () async {
      await db.execute(
        'CREATE TABLE parent_notifications (id INTEGER PRIMARY KEY, parent_user_id INTEGER, learner_user_id INTEGER, alert_type TEXT, class_name TEXT, created_at INTEGER)',
      );
      await db.insert('parent_notifications', {
        'id': 5,
        'parent_user_id': 1,
        'learner_user_id': 2,
        'alert_type': 'negativeUsageWarning',
        'class_name': 'tulong',
        'created_at': now.millisecondsSinceEpoch,
      });
      expect(
        await repo.findTeacherNegativeUsageWarningToday(
          teacherUserId: 1,
          learnerUserId: 2,
          phraseKey: 'help',
          dayStart: day,
        ),
        5,
      );
      expect(
        await repo.findTeacherNegativeUsageWarningToday(
          teacherUserId: 1,
          learnerUserId: 2,
          phraseKey: 'help',
          dayStart: day.add(const Duration(days: 1)),
        ),
        isNull,
      );
    },
  );
}
