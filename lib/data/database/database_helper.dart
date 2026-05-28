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
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            full_name TEXT NOT NULL,
            role TEXT NOT NULL,
            theme TEXT,
            settings_json TEXT
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
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await _upgradeBuiltinPhraseImages(db);
        }
      },
    );
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
