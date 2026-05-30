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
      version: 9,
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
            is_active INTEGER NOT NULL DEFAULT 1
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
            created_at INTEGER NOT NULL
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
      },
    );
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
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS lesson_phrases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lesson_id INTEGER NOT NULL,
        phrase_text TEXT NOT NULL,
        image_path TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createParentNotificationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS parent_notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent_user_id INTEGER NOT NULL,
        learner_user_id INTEGER,
        child_name TEXT NOT NULL,
        alert_type TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0
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
