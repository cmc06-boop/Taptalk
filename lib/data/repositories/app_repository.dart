import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/l10n/content_localization.dart';
import '../database/database_helper.dart';
import '../models/category_model.dart';
import '../models/favorite_model.dart';
import '../models/history_model.dart';
import '../models/enrolled_class_model.dart';
import '../models/linked_child_model.dart';
import '../models/phrase_model.dart';
import '../models/phrase_usage_stat.dart';
import '../models/user_model.dart';

class AppRepository {
  AppRepository(this._dbHelper);

  final DatabaseHelper _dbHelper;

  /// Bundled images for built-in phrases (offline + matches UI prototype).
  static const Map<String, String> _builtinImageUrls = {
    'I am happy': 'assets/images/phrase_happy.jpg',
    'I feel sad': 'assets/images/phrase_sad.jpg',
    'I want pizza': 'assets/images/phrase_pizza.jpg',
    'I want water': 'assets/images/phrase_water.jpg',
    'I want to sleep': 'assets/images/phrase_sleep.jpg',
    'I want to see a dog': 'assets/images/phrase_dog.jpg',
  };

  static const _profileCodeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String hashPassword(String password) {
    final bytes = utf8.encode('taptalk_salt::$password');
    return sha256.convert(bytes).toString();
  }

  /// System-generated learner link code (not chosen by the user).
  static String generateProfileCode() {
    final random = Random.secure();
    final buffer = StringBuffer('TT-');
    for (var i = 0; i < 8; i++) {
      buffer.write(_profileCodeChars[random.nextInt(_profileCodeChars.length)]);
    }
    return buffer.toString();
  }

  /// Legacy deterministic code (user id). Kept so older accounts still link.
  static String profileCodeFor(int userId) {
    final hex = userId.toRadixString(16).toUpperCase();
    return 'TT-${hex.padLeft(10, '0')}';
  }

  static String normalizeCategoryKey(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  Future<UserModel?> findUserByEmail(String email) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserModel.fromMap(rows.first);
  }

  Future<UserModel?> findUserById(int id) async {
    final db = await _dbHelper.database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return UserModel.fromMap(rows.first);
  }

  Future<UserModel> registerUser({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    final db = await _dbHelper.database;
    final settings = <String, dynamic>{
      'language': 'English',
      'tts_speed': 1.0,
    };
    if (role == 'learner') {
      settings['profile_code'] = generateProfileCode();
    }
    final id = await db.insert('users', {
      'email': email.trim().toLowerCase(),
      'password_hash': hashPassword(password),
      'full_name': fullName.trim(),
      'role': role,
      'theme': role == 'learner' ? null : 'mint_green',
      'settings_json': jsonEncode(settings),
    });
    final user = (await findUserById(id))!;
    if (role == 'learner' || role == 'parent') {
      await seedLearnerData(user.id);
    } else if (role == 'teacher') {
      await createDefaultTeacherClass(user.id);
    }
    return user;
  }

  Future<bool> verifyLogin(String email, String password) async {
    final user = await findUserByEmail(email);
    if (user == null || user.passwordHash == null) return false;
    return user.passwordHash == hashPassword(password);
  }

  Future<void> updateUserTheme(int userId, String themeKey) async {
    final db = await _dbHelper.database;
    await db.update('users', {'theme': themeKey}, where: 'id = ?', whereArgs: [userId]);
  }

  Future<void> updateUserFullName(int userId, String fullName) async {
    final db = await _dbHelper.database;
    await db.update(
      'users',
      {'full_name': fullName.trim()},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<bool> updateUserPassword(int userId, String currentPassword, String newPassword) async {
    final user = await findUserById(userId);
    if (user == null || user.passwordHash != hashPassword(currentPassword)) {
      return false;
    }
    final db = await _dbHelper.database;
    await db.update(
      'users',
      {'password_hash': hashPassword(newPassword)},
      where: 'id = ?',
      whereArgs: [userId],
    );
    return true;
  }

  Future<String> ensureLearnerProfileCode(int userId) async {
    final settings = await getUserSettings(userId);
    final existing = settings['profile_code'] as String?;
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }
    // Stable per user so it matches what parents may already have written down.
    final code = profileCodeFor(userId);
    await updateUserSettings(userId, profileCode: code);
    return code;
  }

  Future<void> updateUserSettings(
    int userId, {
    String? language,
    double? ttsSpeed,
    String? profileCode,
  }) async {
    final db = await _dbHelper.database;
    final user = await findUserById(userId);
    if (user == null) return;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [userId], limit: 1);
    Map<String, dynamic> settings = {};
    if (rows.isNotEmpty && rows.first['settings_json'] != null) {
      settings = jsonDecode(rows.first['settings_json'] as String) as Map<String, dynamic>;
    }
    if (language != null) settings['language'] = language;
    if (ttsSpeed != null) settings['tts_speed'] = ttsSpeed;
    if (profileCode != null) settings['profile_code'] = profileCode;
    await db.update(
      'users',
      {'settings_json': jsonEncode(settings)},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> updateEmergencyContacts(int userId, List<String> contacts) async {
    final db = await _dbHelper.database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [userId], limit: 1);
    if (rows.isEmpty) return;
    Map<String, dynamic> settings = {};
    if (rows.first['settings_json'] != null) {
      settings = jsonDecode(rows.first['settings_json'] as String) as Map<String, dynamic>;
    }
    final cleaned = contacts
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .take(2)
        .toList();
    settings['emergency_contacts'] = cleaned;
    await db.update(
      'users',
      {'settings_json': jsonEncode(settings)},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<Map<String, dynamic>> getUserSettings(int userId) async {
    final db = await _dbHelper.database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [userId], limit: 1);
    if (rows.isEmpty || rows.first['settings_json'] == null) {
      return {'language': 'English', 'tts_speed': 1.0};
    }
    return jsonDecode(rows.first['settings_json'] as String) as Map<String, dynamic>;
  }

  Future<void> seedLearnerData(int userId) async {
    final db = await _dbHelper.database;
    final defaults = [
      ('feelings', 'Feelings', 'feelings'),
      ('food', 'Food', 'food'),
      ('drinks', 'Drinks', 'drinks'),
      ('activities', 'Activities', 'activities'),
      ('animals', 'Animals', 'animals'),
    ];
    for (final (key, name, icon) in defaults) {
      await db.insert('categories', {
        'user_id': userId,
        'category_key': key,
        'category_name': name,
        'icon_key': icon,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    final builtinPhrases = [
      ('I am happy', 'feelings', _builtinImageUrls['I am happy']!),
      ('I feel sad', 'feelings', _builtinImageUrls['I feel sad']!),
      ('I want pizza', 'food', _builtinImageUrls['I want pizza']!),
      ('I want water', 'drinks', _builtinImageUrls['I want water']!),
      ('I want to sleep', 'activities', _builtinImageUrls['I want to sleep']!),
      ('I want to see a dog', 'animals', _builtinImageUrls['I want to see a dog']!),
    ];
    for (final (text, cat, img) in builtinPhrases) {
      await db.insert('phrases', {
        'user_id': userId,
        'phrase_text': text,
        'category_key': cat,
        'image_path': img,
        'is_builtin': 1,
        'is_active': 1,
      });
    }
  }

  Future<List<CategoryModel>> getCategories(int userId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'categories',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id ASC',
    );
    return rows.map(CategoryModel.fromMap).toList();
  }

  Future<CategoryModel> addCategory(int userId, String name) async {
    final db = await _dbHelper.database;
    final key = normalizeCategoryKey(name);
    if (key.isEmpty) throw ArgumentError('Invalid category name');
    final existing = await db.query(
      'categories',
      where: 'user_id = ? AND category_key = ?',
      whereArgs: [userId, key],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return CategoryModel.fromMap(existing.first);
    }
    final id = await db.insert('categories', {
      'user_id': userId,
      'category_key': key,
      'category_name': name.trim(),
      'icon_key': 'custom',
    });
    return CategoryModel(
      id: id,
      userId: userId,
      key: key,
      name: name.trim(),
    );
  }

  Future<List<PhraseModel>> getPhrases(int userId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'phrases',
      where: 'user_id = ? AND is_active = 1',
      whereArgs: [userId],
      orderBy: 'id DESC',
    );
    return rows.map(PhraseModel.fromMap).toList();
  }

  Future<PhraseModel> addPhrase({
    required int userId,
    required String text,
    required String categoryKey,
    String? imagePath,
  }) async {
    final db = await _dbHelper.database;
    final id = await db.insert('phrases', {
      'user_id': userId,
      'phrase_text': text.trim(),
      'category_key': categoryKey,
      'image_path': imagePath,
      'is_builtin': 0,
      'is_active': 1,
    });
    return PhraseModel(
      id: id,
      userId: userId,
      text: text.trim(),
      categoryKey: categoryKey,
      imagePath: imagePath,
    );
  }

  Future<void> deletePhrase(int userId, int phraseId) async {
    final db = await _dbHelper.database;
    await db.update(
      'phrases',
      {'is_active': 0},
      where: 'id = ? AND user_id = ? AND is_builtin = 0',
      whereArgs: [phraseId, userId],
    );
  }

  Future<List<FavoriteModel>> getFavorites(int userId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'favorites',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id DESC',
    );
    return rows.map(FavoriteModel.fromMap).toList();
  }

  Future<FavoriteModel?> findFavorite(int userId, String text, String categoryKey) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'favorites',
      where: 'user_id = ? AND phrase_text = ? AND category_key = ?',
      whereArgs: [userId, text.trim(), categoryKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return FavoriteModel.fromMap(rows.first);
  }

  Future<FavoriteModel> addFavorite({
    required int userId,
    required String phraseText,
    required String categoryKey,
    int? phraseId,
    String? imagePath,
  }) async {
    final db = await _dbHelper.database;
    final existing = await findFavorite(userId, phraseText, categoryKey);
    if (existing != null) return existing;
    final id = await db.insert('favorites', {
      'user_id': userId,
      'phrase_text': phraseText.trim(),
      'category_key': categoryKey,
      'phrase_id': phraseId,
      'image_path': imagePath,
    });
    return FavoriteModel(
      id: id,
      userId: userId,
      phraseText: phraseText.trim(),
      categoryKey: categoryKey,
      phraseId: phraseId,
      imagePath: imagePath,
    );
  }

  Future<void> removeFavorite(int favoriteId) async {
    final db = await _dbHelper.database;
    await db.delete('favorites', where: 'id = ?', whereArgs: [favoriteId]);
  }

  Future<List<HistoryModel>> getHistory(int userId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'history',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map(HistoryModel.fromMap).toList();
  }

  Future<void> addHistory({
    required int userId,
    required String text,
    required String categoryKey,
  }) async {
    if (text.trim().isEmpty) return;
    final db = await _dbHelper.database;
    await db.insert('history', {
      'user_id': userId,
      'phrase_text': text.trim(),
      'category_key': categoryKey,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> removeHistory(int historyId) async {
    final db = await _dbHelper.database;
    await db.delete('history', where: 'id = ?', whereArgs: [historyId]);
  }

  Future<void> clearHistory(int userId) async {
    final db = await _dbHelper.database;
    await db.delete('history', where: 'user_id = ?', whereArgs: [userId]);
  }

  static String normalizeProfileCode(String code) {
    var normalized = code.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    normalized = normalized.replaceAll(RegExp(r'[–—−]'), '-');
    if (normalized.startsWith('TT') && !normalized.startsWith('TT-')) {
      final suffix = normalized.substring(2);
      if (suffix.length == 8 || suffix.length == 10) {
        normalized = 'TT-$suffix';
      }
    }
    if (!normalized.startsWith('TT-') && normalized.length == 8) {
      normalized = 'TT-$normalized';
    }
    return normalized;
  }

  static bool isValidProfileCodeFormat(String normalized) {
    if (normalized.isEmpty) return false;
    return RegExp(r'^TT-[A-Z2-9]{8}$').hasMatch(normalized) ||
        RegExp(r'^TT-[0-9A-F]{10}$').hasMatch(normalized);
  }

  Future<UserModel?> findLearnerByProfileCode(String code) async {
    final normalized = normalizeProfileCode(code);
    if (!isValidProfileCodeFormat(normalized)) return null;
    final db = await _dbHelper.database;
    final rows = await db.query(
      'users',
      where: "role = 'learner'",
    );
    for (final row in rows) {
      final learnerId = row['id'] as int;
      final legacy = profileCodeFor(learnerId);
      if (normalizeProfileCode(legacy) == normalized) {
        return UserModel.fromMap(row);
      }

      final settingsRaw = row['settings_json'];
      if (settingsRaw == null) continue;
      final settings = jsonDecode(settingsRaw as String) as Map<String, dynamic>;
      final stored = settings['profile_code'] as String?;
      if (stored != null &&
          stored.trim().isNotEmpty &&
          normalizeProfileCode(stored) == normalized) {
        return UserModel.fromMap(row);
      }
    }
    return null;
  }

  Future<List<LinkedChildModel>> getLinkedChildren(int parentUserId) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT pc.learner_user_id, pc.linked_at, u.full_name, u.settings_json
      FROM parent_children pc
      INNER JOIN users u ON u.id = pc.learner_user_id
      WHERE pc.parent_user_id = ?
      ORDER BY pc.linked_at ASC
    ''', [parentUserId]);
    return rows.map((row) {
      Map<String, dynamic> settings = {};
      final settingsRaw = row['settings_json'];
      if (settingsRaw != null) {
        settings = jsonDecode(settingsRaw as String) as Map<String, dynamic>;
      }
      return LinkedChildModel(
        learnerId: row['learner_user_id'] as int,
        fullName: row['full_name'] as String,
        profileCode: (settings['profile_code'] as String?) ?? '',
        linkedAt: DateTime.fromMillisecondsSinceEpoch(row['linked_at'] as int),
      );
    }).toList();
  }

  Future<bool> isChildLinked(int parentUserId, int learnerUserId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'parent_children',
      where: 'parent_user_id = ? AND learner_user_id = ?',
      whereArgs: [parentUserId, learnerUserId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> linkParentToChild(int parentUserId, int learnerUserId) async {
    final db = await _dbHelper.database;
    await db.insert(
      'parent_children',
      {
        'parent_user_id': parentUserId,
        'learner_user_id': learnerUserId,
        'linked_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> unlinkParentChild(int parentUserId, int learnerUserId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'parent_children',
      where: 'parent_user_id = ? AND learner_user_id = ?',
      whereArgs: [parentUserId, learnerUserId],
    );
  }

  Future<List<PhraseUsageStat>> getPhraseUsageStats({
    required int learnerUserId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT phrase_text, category_key, COUNT(*) AS usage_count
      FROM history
      WHERE user_id = ?
        AND created_at >= ?
        AND created_at < ?
      GROUP BY phrase_text, category_key
      ORDER BY usage_count DESC, phrase_text ASC
    ''', [
      learnerUserId,
      rangeStart.millisecondsSinceEpoch,
      rangeEnd.millisecondsSinceEpoch,
    ]);
    final merged = <String, PhraseUsageStat>{};
    for (final row in rows) {
      final canonical = ContentLocalization.canonicalPhrase(
        row['phrase_text'] as String,
      );
      final categoryKey = normalizeCategoryKey(row['category_key'] as String);
      final count = row['usage_count'] as int;
      final mergeKey = '$categoryKey|$canonical';
      final existing = merged[mergeKey];
      if (existing == null) {
        merged[mergeKey] = PhraseUsageStat(
          text: canonical,
          categoryKey: categoryKey,
          count: count,
        );
      } else {
        merged[mergeKey] = PhraseUsageStat(
          text: canonical,
          categoryKey: categoryKey,
          count: existing.count + count,
        );
      }
    }
    return merged.values.toList()
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        if (byCount != 0) return byCount;
        return a.text.compareTo(b.text);
      });
  }

  static String generateClassCode() {
    final random = Random.secure();
    final buffer = StringBuffer('CLS-');
    for (var i = 0; i < 8; i++) {
      buffer.write(_profileCodeChars[random.nextInt(_profileCodeChars.length)]);
    }
    return buffer.toString();
  }

  static String normalizeClassCode(String code) {
    var normalized = code.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    normalized = normalized.replaceAll(RegExp(r'[–—−]'), '-');
    if (normalized.startsWith('CLS') && !normalized.startsWith('CLS-')) {
      final suffix = normalized.substring(3);
      if (suffix.length == 8) {
        normalized = 'CLS-$suffix';
      }
    }
    if (!normalized.startsWith('CLS-') && normalized.length == 8) {
      normalized = 'CLS-$normalized';
    }
    return normalized;
  }

  static bool isValidClassCodeFormat(String normalized) {
    if (normalized.isEmpty) return false;
    return RegExp(r'^CLS-[A-Z2-9]{8}$').hasMatch(normalized) ||
        RegExp(r'^CLS-[0-9A-F]{8}$').hasMatch(normalized);
  }

  Future<void> createDefaultTeacherClass(int teacherUserId) async {
    final db = await _dbHelper.database;
    final existing = await db.query(
      'teacher_classes',
      where: 'teacher_user_id = ?',
      whereArgs: [teacherUserId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    await db.insert('teacher_classes', {
      'teacher_user_id': teacherUserId,
      'class_name': 'My Class',
      'class_code': generateClassCode(),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<Map<String, Object?>?> findClassByCode(String code) async {
    final normalized = normalizeClassCode(code);
    if (!isValidClassCodeFormat(normalized)) return null;
    final db = await _dbHelper.database;
    final rows = await db.query(
      'teacher_classes',
      where: 'class_code = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<bool> isLearnerEnrolled(int learnerUserId, int classId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'class_enrollments',
      where: 'learner_user_id = ? AND class_id = ?',
      whereArgs: [learnerUserId, classId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> enrollLearnerInClass(int learnerUserId, int classId) async {
    final db = await _dbHelper.database;
    await db.insert(
      'class_enrollments',
      {
        'learner_user_id': learnerUserId,
        'class_id': classId,
        'enrolled_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> unenrollLearnerFromClass(int learnerUserId, int classId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'class_enrollments',
      where: 'learner_user_id = ? AND class_id = ?',
      whereArgs: [learnerUserId, classId],
    );
  }

  Future<List<({int id, String name, String code})>> getTeacherClasses(
    int teacherUserId,
  ) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'teacher_classes',
      columns: ['id', 'class_name', 'class_code'],
      where: 'teacher_user_id = ?',
      whereArgs: [teacherUserId],
      orderBy: 'created_at ASC',
    );
    return rows
        .map(
          (row) => (
            id: row['id'] as int,
            name: row['class_name'] as String,
            code: row['class_code'] as String,
          ),
        )
        .toList();
  }

  Future<List<EnrolledClassModel>> getEnrolledClasses(int learnerUserId) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT
        tc.id AS class_id,
        tc.class_name,
        tc.class_code,
        tc.teacher_user_id AS teacher_id,
        u.full_name AS teacher_name,
        ce.enrolled_at
      FROM class_enrollments ce
      INNER JOIN teacher_classes tc ON tc.id = ce.class_id
      INNER JOIN users u ON u.id = tc.teacher_user_id
      WHERE ce.learner_user_id = ?
      ORDER BY ce.enrolled_at ASC
    ''', [learnerUserId]);
    return rows.map(EnrolledClassModel.fromMap).toList();
  }
}
