import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'taptalk.db');

    return openDatabase(
      path,
      version: 17,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            full_name TEXT NOT NULL,
            role TEXT NOT NULL,
            theme TEXT,
            settings_json TEXT,
            firebase_uid TEXT UNIQUE
          )
        ''');
        await db.execute('''
          CREATE TABLE categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            category_key TEXT NOT NULL,
            category_name TEXT NOT NULL,
            icon_key TEXT DEFAULT 'custom',
            UNIQUE(user_id, category_key)
          )
        ''');
        await db.execute('''
          CREATE TABLE phrases (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            phrase_text TEXT NOT NULL,
            category_key TEXT NOT NULL,
            image_path TEXT,
            is_builtin INTEGER NOT NULL DEFAULT 0,
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE favorites (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            phrase_text TEXT NOT NULL,
            category_key TEXT NOT NULL,
            phrase_id INTEGER,
            image_path TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            phrase_text TEXT NOT NULL,
            category_key TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            class_name TEXT,
            lesson_title TEXT
          )
        ''');
        await _createParentChildrenTable(db);
        await _createClassTables(db);
        await _createParentNotificationsTable(db);
        await _createLessonTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await _upgradeBuiltinPhraseImages(db);
        }
        if (oldVersion < 4) {
          await _createParentChildrenTable(db);
        }
        if (oldVersion < 5) {
          await _backfillLearnerProfileCodes(db);
        }
        if (oldVersion < 6) {
          await _createClassTables(db);
          await _backfillTeacherClasses(db);
        }
        if (oldVersion < 7) {
          await _createParentNotificationsTable(db);
        }
        if (oldVersion < 8) {
          await _createLessonTables(db);
        }
        if (oldVersion < 9) {
          await db.execute('ALTER TABLE users ADD COLUMN firebase_uid TEXT');
          await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_users_firebase_uid '
            'ON users(firebase_uid) WHERE firebase_uid IS NOT NULL',
          );
        }
        if (oldVersion < 10) {
          await db.execute(
            'ALTER TABLE parent_notifications ADD COLUMN remote_id TEXT',
          );
          await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_parent_notifications_remote_id '
            'ON parent_notifications(remote_id) WHERE remote_id IS NOT NULL',
          );
        }
        if (oldVersion < 11) {
          await db.execute('ALTER TABLE history ADD COLUMN class_name TEXT');
          await db.execute('ALTER TABLE history ADD COLUMN lesson_title TEXT');
        }
        if (oldVersion < 12) {
          await _canonicalizeLessonContent(db);
        }
        if (oldVersion < 13) {
          await db.execute(
            'ALTER TABLE class_lessons ADD COLUMN cloud_lesson_key TEXT',
          );
          await db.execute(
            'ALTER TABLE lesson_phrases ADD COLUMN cloud_phrase_key TEXT',
          );
          await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_class_lessons_cloud_key '
            'ON class_lessons(class_id, cloud_lesson_key) '
            'WHERE cloud_lesson_key IS NOT NULL',
          );
        }
        if (oldVersion < 14) {
          await db.execute(
            'ALTER TABLE history ADD COLUMN remote_sync_key TEXT',
          );
          await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_history_remote_sync_key '
            'ON history(user_id, remote_sync_key) '
            'WHERE remote_sync_key IS NOT NULL',
          );
        }
        if (oldVersion < 15) {
          await db.execute(
            'ALTER TABLE parent_notifications ADD COLUMN teacher_user_id INTEGER',
          );
          await db.execute(
            'ALTER TABLE parent_notifications ADD COLUMN class_id INTEGER',
          );
          await db.execute(
            'ALTER TABLE parent_notifications ADD COLUMN class_name TEXT',
          );
          await db.execute('''
            UPDATE parent_notifications
            SET
              teacher_user_id = (
                SELECT tc.teacher_user_id
                FROM class_enrollments ce
                INNER JOIN teacher_classes tc ON tc.id = ce.class_id
                WHERE ce.learner_user_id = parent_notifications.learner_user_id
                ORDER BY ce.enrolled_at DESC
                LIMIT 1
              ),
              class_id = (
                SELECT ce.class_id
                FROM class_enrollments ce
                INNER JOIN teacher_classes tc ON tc.id = ce.class_id
                WHERE ce.learner_user_id = parent_notifications.learner_user_id
                ORDER BY ce.enrolled_at DESC
                LIMIT 1
              ),
              class_name = (
                SELECT tc.class_name
                FROM class_enrollments ce
                INNER JOIN teacher_classes tc ON tc.id = ce.class_id
                WHERE ce.learner_user_id = parent_notifications.learner_user_id
                ORDER BY ce.enrolled_at DESC
                LIMIT 1
              )
            WHERE teacher_user_id IS NULL
          ''');
        }
        if (oldVersion < 16) {
          await db.execute(
            'ALTER TABLE phrases ADD COLUMN created_at INTEGER',
          );
        }
        if (oldVersion < 17) {
          await _dedupeAllBuiltinPhrases(db);
          await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_phrases_builtin_unique '
            'ON phrases(user_id, phrase_text, category_key) '
            'WHERE is_builtin = 1',
          );
        }
      },
    );
  }

  Future<void> _dedupeAllBuiltinPhrases(Database db) async {
    final rows = await db.query(
      'phrases',
      columns: ['id', 'user_id', 'phrase_text', 'category_key'],
      where: 'is_builtin = 1',
      orderBy: 'id ASC',
    );
    final seen = <String>{};
    for (final row in rows) {
      final key =
          '${row['user_id']}|${row['phrase_text']}|${row['category_key']}';
      if (!seen.add(key)) {
        await db.delete('phrases', where: 'id = ?', whereArgs: [row['id']]);
      }
    }
  }

  Future<void> _backfillLearnerProfileCodes(Database db) async {
    final rows = await db.query('users', where: "role = 'learner'");
    for (final row in rows) {
      final id = row['id'] as int;
      Map<String, dynamic> settings = {};
      final raw = row['settings_json'];
      if (raw != null) {
        settings = jsonDecode(raw as String) as Map<String, dynamic>;
      }
      final existing = settings['profile_code'] as String?;
      if (existing != null && existing.trim().isNotEmpty) continue;
      final hex = id.toRadixString(16).toUpperCase();
      settings['profile_code'] = 'TT-${hex.padLeft(10, '0')}';
      await db.update(
        'users',
        {'settings_json': jsonEncode(settings)},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> _createLessonTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS class_lessons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        cloud_lesson_key TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lesson_phrases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lesson_id INTEGER NOT NULL,
        phrase_text TEXT NOT NULL,
        image_path TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        cloud_phrase_key TEXT
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_class_lessons_cloud_key '
      'ON class_lessons(class_id, cloud_lesson_key) '
      'WHERE cloud_lesson_key IS NOT NULL',
    );
  }

  Future<void> _createParentNotificationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS parent_notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent_user_id INTEGER NOT NULL,
        learner_user_id INTEGER,
        teacher_user_id INTEGER,
        class_id INTEGER,
        class_name TEXT,
        child_name TEXT NOT NULL,
        alert_type TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0,
        remote_id TEXT
      )
    ''');
  }

  Future<void> _createParentChildrenTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS parent_children (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent_user_id INTEGER NOT NULL,
        learner_user_id INTEGER NOT NULL,
        linked_at INTEGER NOT NULL,
        UNIQUE(parent_user_id, learner_user_id)
      )
    ''');
  }

  Future<void> _createClassTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS teacher_classes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        teacher_user_id INTEGER NOT NULL,
        class_name TEXT NOT NULL,
        class_code TEXT NOT NULL UNIQUE,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS class_enrollments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        learner_user_id INTEGER NOT NULL,
        class_id INTEGER NOT NULL,
        enrolled_at INTEGER NOT NULL,
        UNIQUE(learner_user_id, class_id)
      )
    ''');
  }

  Future<void> _backfillTeacherClasses(Database db) async {
    final teachers = await db.query('users', where: "role = 'teacher'");
    for (final row in teachers) {
      final teacherId = row['id'] as int;
      final existing = await db.query(
        'teacher_classes',
        where: 'teacher_user_id = ?',
        whereArgs: [teacherId],
        limit: 1,
      );
      if (existing.isNotEmpty) continue;
      final code =
          'CLS-${teacherId.toRadixString(16).toUpperCase().padLeft(8, '0')}';
      await db.insert('teacher_classes', {
        'teacher_user_id': teacherId,
        'class_name': 'My Class',
        'class_code': code,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  Future<void> _canonicalizeLessonContent(Database db) async {
    // Legacy migration hook: user-entered lesson text is stored as typed.
  }

  Future<void> _upgradeBuiltinPhraseImages(Database db) async {
    const urls = {
      'I am happy': 'assets/images/phrase_happy.jpg',
      'I feel sad': 'assets/images/phrase_sad.jpg',
      'I want pizza': 'assets/images/phrase_pizza.jpg',
      'I want water': 'assets/images/phrase_water.jpg',
      'I want to sleep': 'assets/images/phrase_sleep.jpg',
      'I want to see a dog': 'assets/images/phrase_dog.jpg',
    };
    for (final entry in urls.entries) {
      await db.update(
        'phrases',
        {'image_path': entry.value},
        where: 'phrase_text = ? AND is_builtin = 1',
        whereArgs: [entry.key],
      );
    }
  }
}
