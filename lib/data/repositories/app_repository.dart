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
import '../models/parent_notification.dart';
import '../models/teacher_recent_alert.dart';
import '../models/teacher_recent_lesson.dart';
import '../models/phrase_first_use.dart';
import '../models/phrase_usage_stat.dart';
import '../models/class_lesson.dart';
import '../models/lesson_phrase.dart';
import '../models/teacher_alert_result.dart';
import '../models/teacher_class_student.dart';
import '../models/user_model.dart';
import '../../services/cloud_notification_backend.dart';

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

  Future<UserModel?> findUserByFirebaseUid(String firebaseUid) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'users',
      where: 'firebase_uid = ?',
      whereArgs: [firebaseUid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserModel.fromMap(rows.first);
  }

  Future<void> linkFirebaseUid(int userId, String firebaseUid) async {
    final db = await _dbHelper.database;
    await db.update(
      'users',
      {'firebase_uid': firebaseUid},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> updatePasswordHash(int userId, String password) async {
    final db = await _dbHelper.database;
    await db.update(
      'users',
      {'password_hash': hashPassword(password)},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<UserModel> registerUser({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String? firebaseUid,
  }) async {
    final db = await _dbHelper.database;
    final settings = <String, dynamic>{
      'language': 'English',
      'tts_speed': 0.25,
    };
    if (role == 'learner') {
      settings['profile_code'] = generateProfileCode();
    }
    final row = <String, Object?>{
      'email': email.trim().toLowerCase(),
      'password_hash': hashPassword(password),
      'full_name': fullName.trim(),
      'role': role,
      'theme': role == 'learner' ? null : 'mint_green',
      'settings_json': jsonEncode(settings),
    };
    var uidToStore = firebaseUid;
    late int id;
    try {
      if (uidToStore != null) {
        row['firebase_uid'] = uidToStore;
      }
      id = await db.insert('users', row);
    } on DatabaseException catch (e) {
      final msg = e.toString().toLowerCase();
      if (uidToStore != null &&
          (msg.contains('unique') || msg.contains('constraint'))) {
        row.remove('firebase_uid');
        uidToStore = null;
        id = await db.insert('users', row);
      } else {
        rethrow;
      }
    }
    final user = (await findUserById(id))!;
    if (role == 'learner' || role == 'parent') {
      await seedLearnerData(user.id);
    }
    return user;
  }

  Future<bool> verifyLogin(String email, String password) async {
    final user = await findUserByEmail(email);
    if (user == null ||
        user.passwordHash == null ||
        user.passwordHash!.isEmpty) {
      return false;
    }
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

  Future<bool> resetPasswordByEmail(String email, String newPassword) async {
    final user = await findUserByEmail(email);
    if (user == null) return false;
    final db = await _dbHelper.database;
    await db.update(
      'users',
      {'password_hash': hashPassword(newPassword)},
      where: 'id = ?',
      whereArgs: [user.id],
    );
    return true;
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
      return {'language': 'English', 'tts_speed': 0.25};
    }
    return jsonDecode(rows.first['settings_json'] as String) as Map<String, dynamic>;
  }

  Future<List<String>> getEmergencyContactsForLearner(int learnerUserId) async {
    final user = await findUserById(learnerUserId);
    if (user == null || !user.isLearner) return const [];
    final settings = await getUserSettings(learnerUserId);
    final contacts = settings['emergency_contacts'];
    if (contacts is! List) return const [];
    return contacts
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(2)
        .toList();
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
      await db.insert(
        'phrases',
        {
          'user_id': userId,
          'phrase_text': text,
          'category_key': cat,
          'image_path': img,
          'is_builtin': 1,
          'is_active': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
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

  Future<List<DateTime>> getHistoryTimestamps({
    required int learnerUserId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT created_at
      FROM history
      WHERE user_id = ?
        AND created_at >= ?
        AND created_at < ?
      ORDER BY created_at ASC
    ''', [
      learnerUserId,
      rangeStart.millisecondsSinceEpoch,
      rangeEnd.millisecondsSinceEpoch,
    ]);
    return rows
        .map(
          (row) => DateTime.fromMillisecondsSinceEpoch(
            row['created_at'] as int,
          ),
        )
        .toList();
  }

  Future<List<PhraseFirstUse>> getPhraseFirstUses({
    required int learnerUserId,
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT phrase_text, category_key, MIN(created_at) AS first_used_at
      FROM history
      WHERE user_id = ?
      GROUP BY phrase_text, category_key
    ''', [learnerUserId]);

    final merged = <String, PhraseFirstUse>{};
    for (final row in rows) {
      final canonical = ContentLocalization.canonicalPhrase(
        row['phrase_text'] as String,
      );
      final categoryKey = normalizeCategoryKey(row['category_key'] as String);
      final firstUsedAt = DateTime.fromMillisecondsSinceEpoch(
        row['first_used_at'] as int,
      );
      final mergeKey = '$categoryKey|$canonical';
      final existing = merged[mergeKey];
      if (existing == null || firstUsedAt.isBefore(existing.firstUsedAt)) {
        merged[mergeKey] = PhraseFirstUse(
          text: canonical,
          categoryKey: categoryKey,
          firstUsedAt: firstUsedAt,
        );
      }
    }

    return merged.values.toList()
      ..sort((a, b) => a.firstUsedAt.compareTo(b.firstUsedAt));
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

  Future<({String? error, int id, String code, String name})> createTeacherClass({
    required int teacherUserId,
    required String className,
  }) async {
    final trimmed = className.trim();
    if (trimmed.isEmpty) {
      return (error: 'empty', id: 0, code: '', name: '');
    }
    final db = await _dbHelper.database;
    var code = generateClassCode();
    for (var attempt = 0; attempt < 8; attempt++) {
      final clash = await db.query(
        'teacher_classes',
        where: 'class_code = ?',
        whereArgs: [code],
        limit: 1,
      );
      if (clash.isEmpty) break;
      code = generateClassCode();
    }
    final id = await db.insert('teacher_classes', {
      'teacher_user_id': teacherUserId,
      'class_name': trimmed,
      'class_code': code,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    return (error: null, id: id, code: code, name: trimmed);
  }

  Future<bool> deleteTeacherClass({
    required int teacherUserId,
    required int classId,
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'teacher_classes',
      where: 'id = ? AND teacher_user_id = ?',
      whereArgs: [classId, teacherUserId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    await db.delete(
      'class_enrollments',
      where: 'class_id = ?',
      whereArgs: [classId],
    );
    await db.delete(
      'teacher_classes',
      where: 'id = ?',
      whereArgs: [classId],
    );
    return true;
  }

  Future<int> countStudentsInClass(int classId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM class_enrollments WHERE class_id = ?',
      [classId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
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

  Future<Map<String, Object?>?> findClassById(int classId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'teacher_classes',
      where: 'id = ?',
      whereArgs: [classId],
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

  Future<List<TeacherClassStudent>> getTeacherClassStudents(
    int teacherUserId,
  ) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT
        u.id AS learner_id,
        u.full_name,
        tc.id AS class_id,
        tc.class_name,
        tc.class_code,
        ce.enrolled_at
      FROM class_enrollments ce
      INNER JOIN teacher_classes tc ON tc.id = ce.class_id
      INNER JOIN users u ON u.id = ce.learner_user_id
      WHERE tc.teacher_user_id = ?
      ORDER BY tc.class_name ASC, u.full_name ASC
    ''', [teacherUserId]);
    return rows
        .map(
          (row) => TeacherClassStudent(
            learnerId: row['learner_id'] as int,
            fullName: row['full_name'] as String,
            classId: row['class_id'] as int,
            className: row['class_name'] as String,
            classCode: row['class_code'] as String,
            enrolledAt: DateTime.fromMillisecondsSinceEpoch(
              row['enrolled_at'] as int,
            ),
          ),
        )
        .toList();
  }

  Future<List<TeacherClassStudent>> getTeacherClassStudentsForClass({
    required int teacherUserId,
    required int classId,
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT
        u.id AS learner_id,
        u.full_name,
        tc.id AS class_id,
        tc.class_name,
        tc.class_code,
        ce.enrolled_at
      FROM class_enrollments ce
      INNER JOIN teacher_classes tc ON tc.id = ce.class_id
      INNER JOIN users u ON u.id = ce.learner_user_id
      WHERE tc.teacher_user_id = ? AND tc.id = ?
      ORDER BY u.full_name ASC
    ''', [teacherUserId, classId]);
    return rows
        .map(
          (row) => TeacherClassStudent(
            learnerId: row['learner_id'] as int,
            fullName: row['full_name'] as String,
            classId: row['class_id'] as int,
            className: row['class_name'] as String,
            classCode: row['class_code'] as String,
            enrolledAt: DateTime.fromMillisecondsSinceEpoch(
              row['enrolled_at'] as int,
            ),
          ),
        )
        .toList();
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

  Future<void> mergeRemoteTeacherClasses({
    required int teacherUserId,
    required List<RemoteTeacherClass> remoteClasses,
  }) async {
    if (remoteClasses.isEmpty) return;
    final db = await _dbHelper.database;
    for (final remote in remoteClasses) {
      final code = normalizeClassCode(remote.classCode);
      if (!isValidClassCodeFormat(code)) continue;
      final existing = await findClassByCode(code);
      if (existing == null) {
        await db.insert('teacher_classes', {
          'teacher_user_id': teacherUserId,
          'class_name': remote.className.trim().isEmpty ? 'Class' : remote.className.trim(),
          'class_code': code,
          'created_at': remote.createdAt.millisecondsSinceEpoch,
        });
        continue;
      }
      if ((existing['teacher_user_id'] as int?) != teacherUserId) continue;
      final localName = (existing['class_name'] as String?) ?? '';
      final remoteName = remote.className.trim();
      if (remoteName.isNotEmpty && remoteName != localName) {
        await db.update(
          'teacher_classes',
          {'class_name': remoteName},
          where: 'id = ?',
          whereArgs: [existing['id']],
        );
      }
    }
  }

  Future<void> mergeRemoteEnrollmentsForTeacher({
    required int teacherUserId,
    required List<RemoteClassEnrollment> enrollments,
  }) async {
    if (enrollments.isEmpty) return;
    for (final enrollment in enrollments) {
      final code = normalizeClassCode(enrollment.classCode);
      if (!isValidClassCodeFormat(code)) continue;
      final classRow = await findClassByCode(code);
      if (classRow == null) continue;
      if ((classRow['teacher_user_id'] as int?) != teacherUserId) continue;
      final classId = classRow['id'] as int;
      final learnerUid = enrollment.learnerFirebaseUid.trim();
      if (learnerUid.isEmpty) continue;
      final learner = await findUserByFirebaseUid(learnerUid);
      if (learner == null) continue;
      if (await isLearnerEnrolled(learner.id, classId)) continue;
      await enrollLearnerInClass(learner.id, classId);
    }
  }

  Future<bool> _isLearnerEnrolledInLesson(int learnerUserId, int lessonId) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT ce.id
      FROM class_enrollments ce
      INNER JOIN class_lessons cl ON cl.class_id = ce.class_id
      WHERE ce.learner_user_id = ? AND cl.id = ?
      LIMIT 1
    ''', [learnerUserId, lessonId]);
    return rows.isNotEmpty;
  }

  Future<List<ClassLesson>> getEnrolledClassLessons({
    required int learnerUserId,
    required int classId,
  }) async {
    if (!await isLearnerEnrolled(learnerUserId, classId)) return [];
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT
        cl.id,
        cl.class_id,
        cl.title,
        cl.created_at,
        (SELECT COUNT(*) FROM lesson_phrases lp WHERE lp.lesson_id = cl.id) AS phrase_count
      FROM class_lessons cl
      WHERE cl.class_id = ?
      ORDER BY cl.sort_order ASC, cl.created_at DESC
    ''', [classId]);
    return rows
        .map(
          (row) => ClassLesson(
            id: row['id'] as int,
            classId: row['class_id'] as int,
            title: row['title'] as String,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              row['created_at'] as int,
            ),
            phraseCount: row['phrase_count'] as int? ?? 0,
          ),
        )
        .toList();
  }

  Future<List<LessonPhrase>> getEnrolledLessonPhrases({
    required int learnerUserId,
    required int lessonId,
  }) async {
    if (!await _isLearnerEnrolledInLesson(learnerUserId, lessonId)) return [];
    final db = await _dbHelper.database;
    final rows = await db.query(
      'lesson_phrases',
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows
        .map(
          (row) => LessonPhrase(
            id: row['id'] as int,
            lessonId: row['lesson_id'] as int,
            text: row['phrase_text'] as String,
            imagePath: row['image_path'] as String?,
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

  Future<List<ParentNotification>> getParentNotifications(int parentUserId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'parent_notifications',
      where: 'parent_user_id = ?',
      whereArgs: [parentUserId],
      orderBy: 'created_at DESC',
    );
    return rows.map(_notificationFromRow).toList();
  }

  Future<List<TeacherRecentAlert>> getRecentAlertsForTeacher({
    required int teacherUserId,
    int limit = 4,
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT
        pn.id,
        tc.id AS class_id,
        pn.child_name,
        pn.alert_type,
        pn.created_at,
        tc.class_name
      FROM parent_notifications pn
      INNER JOIN class_enrollments ce ON ce.learner_user_id = pn.learner_user_id
      INNER JOIN teacher_classes tc ON tc.id = ce.class_id
      WHERE tc.teacher_user_id = ?
      ORDER BY pn.created_at DESC
      LIMIT ?
    ''', [teacherUserId, limit]);
    return rows
        .map(
          (row) => TeacherRecentAlert(
            id: row['id'] as int,
            classId: row['class_id'] as int,
            childName: row['child_name'] as String,
            alertType: ParentNotification.alertTypeFromKey(
              row['alert_type'] as String,
            ),
            className: row['class_name'] as String,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              row['created_at'] as int,
            ),
          ),
        )
        .toList();
  }

  Future<List<TeacherRecentLesson>> getRecentLessonsForTeacher({
    required int teacherUserId,
    int limit = 8,
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT
        cl.id,
        cl.class_id,
        cl.title,
        cl.created_at,
        (SELECT COUNT(*) FROM lesson_phrases lp WHERE lp.lesson_id = cl.id) AS phrase_count,
        tc.class_name
      FROM class_lessons cl
      INNER JOIN teacher_classes tc ON tc.id = cl.class_id
      WHERE tc.teacher_user_id = ?
      ORDER BY cl.created_at DESC
      LIMIT ?
    ''', [teacherUserId, limit]);
    return rows
        .map(
          (row) => TeacherRecentLesson(
            id: row['id'] as int,
            classId: row['class_id'] as int,
            title: row['title'] as String,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              row['created_at'] as int,
            ),
            phraseCount: row['phrase_count'] as int? ?? 0,
            className: row['class_name'] as String,
          ),
        )
        .toList();
  }

  Future<List<int>> getLinkedParentIds(int learnerUserId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'parent_children',
      columns: ['parent_user_id'],
      where: 'learner_user_id = ?',
      whereArgs: [learnerUserId],
    );
    return rows.map((row) => row['parent_user_id'] as int).toList();
  }

  Future<bool> isLearnerInTeacherClass({
    required int teacherUserId,
    required int learnerUserId,
    required int classId,
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT ce.id
      FROM class_enrollments ce
      INNER JOIN teacher_classes tc ON tc.id = ce.class_id
      WHERE ce.learner_user_id = ?
        AND ce.class_id = ?
        AND tc.teacher_user_id = ?
      LIMIT 1
    ''', [learnerUserId, classId, teacherUserId]);
    return rows.isNotEmpty;
  }

  Future<TeacherAlertResult> sendTeacherAlertToParents({
    required int teacherUserId,
    required String teacherName,
    required int learnerUserId,
    required String learnerName,
    required int classId,
    required String className,
    required ParentAlertType alertType,
    required String title,
    required String body,
  }) async {
    final authorized = await isLearnerInTeacherClass(
      teacherUserId: teacherUserId,
      learnerUserId: learnerUserId,
      classId: classId,
    );
    if (!authorized) {
      return const TeacherAlertResult(status: TeacherAlertStatus.notAuthorized);
    }

    final parentIds = await getLinkedParentIds(learnerUserId);
    if (parentIds.isEmpty) {
      return const TeacherAlertResult(
        status: TeacherAlertStatus.noLinkedParents,
      );
    }

    final db = await _dbHelper.database;
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    final notificationIds = <int>[];
    for (final parentId in parentIds) {
      final id = await db.insert('parent_notifications', {
        'parent_user_id': parentId,
        'learner_user_id': learnerUserId,
        'child_name': learnerName,
        'alert_type': alertType.name,
        'title': title,
        'body': body,
        'created_at': createdAt,
        'is_read': 0,
      });
      notificationIds.add(id);
    }

    return TeacherAlertResult(
      status: TeacherAlertStatus.sent,
      notificationsSent: notificationIds.length,
      notificationIds: notificationIds,
    );
  }

  Future<int?> parentUserIdForNotification(int notificationId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'parent_notifications',
      columns: ['parent_user_id'],
      where: 'id = ?',
      whereArgs: [notificationId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['parent_user_id'] as int;
  }

  Future<String?> getFirebaseUidForUser(int userId) async {
    final user = await findUserById(userId);
    final uid = user?.firebaseUid;
    if (uid == null || uid.trim().isEmpty) return null;
    return uid.trim();
  }

  Future<void> upsertRemoteParentNotifications({
    required int parentUserId,
    required List<RemoteParentNotification> items,
  }) async {
    if (items.isEmpty) return;
    final db = await _dbHelper.database;
    for (final item in items) {
      if (item.parentUserId != parentUserId) continue;
      final existing = await db.query(
        'parent_notifications',
        where: 'remote_id = ?',
        whereArgs: [item.remoteId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final wasRead = (existing.first['is_read'] as int? ?? 0) == 1;
        final keepRead = wasRead || item.isRead;
        await db.update(
          'parent_notifications',
          {
            'title': item.title,
            'body': item.body,
            'child_name': item.childName,
            'is_read': keepRead ? 1 : 0,
          },
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
        continue;
      }
      await db.insert('parent_notifications', {
        'parent_user_id': parentUserId,
        'learner_user_id': item.learnerUserId,
        'child_name': item.childName,
        'alert_type': item.alertType,
        'title': item.title,
        'body': item.body,
        'created_at': item.createdAt.millisecondsSinceEpoch,
        'is_read': item.isRead ? 1 : 0,
        'remote_id': item.remoteId,
      });
    }
  }

  ParentNotification _notificationFromRow(Map<String, Object?> row) {
    return ParentNotification(
      id: row['id'] as int,
      parentUserId: row['parent_user_id'] as int,
      learnerUserId: row['learner_user_id'] as int?,
      childName: row['child_name'] as String,
      alertType: ParentNotification.alertTypeFromKey(
        row['alert_type'] as String,
      ),
      title: row['title'] as String,
      body: row['body'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      isRead: (row['is_read'] as int) == 1,
    );
  }

  Future<String?> notificationRemoteId(int notificationId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'parent_notifications',
      columns: ['remote_id'],
      where: 'id = ?',
      whereArgs: [notificationId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final remoteId = rows.first['remote_id'] as String?;
    if (remoteId == null || remoteId.trim().isEmpty) return null;
    return remoteId.trim();
  }

  Future<List<String>> unreadNotificationRemoteIds(int parentUserId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'parent_notifications',
      columns: ['remote_id'],
      where: 'parent_user_id = ? AND is_read = 0',
      whereArgs: [parentUserId],
    );
    return rows
        .map((r) => r['remote_id'] as String?)
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> markNotificationRead(int notificationId) async {
    final db = await _dbHelper.database;
    await db.update(
      'parent_notifications',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [notificationId],
    );
  }

  Future<void> markAllNotificationsRead(int parentUserId) async {
    final db = await _dbHelper.database;
    await db.update(
      'parent_notifications',
      {'is_read': 1},
      where: 'parent_user_id = ? AND is_read = 0',
      whereArgs: [parentUserId],
    );
  }

  Future<void> seedParentNotificationsIfEmpty({
    required int parentUserId,
    required String childName,
    int? learnerUserId,
    required bool filipino,
  }) async {
    final db = await _dbHelper.database;
    final existing = await db.query(
      'parent_notifications',
      where: 'parent_user_id = ?',
      whereArgs: [parentUserId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    final now = DateTime.now();
    final samples = filipino
        ? _filipinoNotificationSamples(childName)
        : _englishNotificationSamples(childName);

    for (final sample in samples) {
      await db.insert('parent_notifications', {
        'parent_user_id': parentUserId,
        'learner_user_id': learnerUserId,
        'child_name': childName,
        'alert_type': sample.$1.name,
        'title': sample.$2,
        'body': sample.$3,
        'created_at': now.subtract(sample.$4).millisecondsSinceEpoch,
        'is_read': sample.$5 ? 1 : 0,
      });
    }
  }

  List<(ParentAlertType, String, String, Duration, bool)> _englishNotificationSamples(
    String child,
  ) {
    return [
      (
        ParentAlertType.teacherAlert,
        'Teacher alert — $child',
        'Ms. Reyes sent an urgent alert: $child needs a parent at school as soon as possible.',
        const Duration(minutes: 18),
        false,
      ),
      (
        ParentAlertType.distress,
        '$child may need calming support',
        'TapTalk logged repeated distress phrases. $child may be upset or having a difficult moment.',
        const Duration(hours: 2, minutes: 5),
        false,
      ),
      (
        ParentAlertType.needsAttention,
        'Attention needed for $child',
        '$child used urgent phrases several times in a short period. Please check in when you can.',
        const Duration(hours: 5, minutes: 40),
        true,
      ),
      (
        ParentAlertType.schoolNeeded,
        'School follow-up for $child',
        'The teacher noted $child had a hard transition after break. Your presence or a call may help.',
        const Duration(days: 1, hours: 3),
        true,
      ),
      (
        ParentAlertType.teacherAlert,
        'Classroom support requested',
        'Teacher alert: $child became overwhelmed during group work and may need parent support.',
        const Duration(days: 2, hours: 10),
        true,
      ),
      (
        ParentAlertType.distress,
        'Elevated distress signals',
        'Multiple “I feel sad” and help phrases were used today. Consider a calm check-in with $child.',
        const Duration(days: 4, hours: 6),
        true,
      ),
    ];
  }

  Future<bool> _teacherOwnsClass(int teacherUserId, int classId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'teacher_classes',
      where: 'id = ? AND teacher_user_id = ?',
      whereArgs: [classId, teacherUserId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<bool> _teacherOwnsLesson(int teacherUserId, int lessonId) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT cl.id
      FROM class_lessons cl
      INNER JOIN teacher_classes tc ON tc.id = cl.class_id
      WHERE cl.id = ? AND tc.teacher_user_id = ?
      LIMIT 1
    ''', [lessonId, teacherUserId]);
    return rows.isNotEmpty;
  }

  Future<List<ClassLesson>> getClassLessons({
    required int teacherUserId,
    required int classId,
  }) async {
    if (!await _teacherOwnsClass(teacherUserId, classId)) return [];
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT
        cl.id,
        cl.class_id,
        cl.title,
        cl.created_at,
        (SELECT COUNT(*) FROM lesson_phrases lp WHERE lp.lesson_id = cl.id) AS phrase_count
      FROM class_lessons cl
      WHERE cl.class_id = ?
      ORDER BY cl.sort_order ASC, cl.created_at DESC
    ''', [classId]);
    return rows
        .map(
          (row) => ClassLesson(
            id: row['id'] as int,
            classId: row['class_id'] as int,
            title: row['title'] as String,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              row['created_at'] as int,
            ),
            phraseCount: row['phrase_count'] as int? ?? 0,
          ),
        )
        .toList();
  }

  Future<ClassLesson?> createClassLesson({
    required int teacherUserId,
    required int classId,
    required String title,
  }) async {
    if (!await _teacherOwnsClass(teacherUserId, classId)) return null;
    final trimmed = title.trim();
    if (trimmed.isEmpty) return null;
    final db = await _dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert('class_lessons', {
      'class_id': classId,
      'title': trimmed,
      'created_at': now,
      'sort_order': now,
    });
    return ClassLesson(
      id: id,
      classId: classId,
      title: trimmed,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  Future<bool> deleteClassLesson({
    required int teacherUserId,
    required int lessonId,
  }) async {
    if (!await _teacherOwnsLesson(teacherUserId, lessonId)) return false;
    final db = await _dbHelper.database;
    await db.delete(
      'lesson_phrases',
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
    );
    await db.delete(
      'class_lessons',
      where: 'id = ?',
      whereArgs: [lessonId],
    );
    return true;
  }

  Future<List<LessonPhrase>> getLessonPhrases({
    required int teacherUserId,
    required int lessonId,
  }) async {
    if (!await _teacherOwnsLesson(teacherUserId, lessonId)) return [];
    final db = await _dbHelper.database;
    final rows = await db.query(
      'lesson_phrases',
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
      orderBy: 'sort_order ASC, id ASC',
    );
    return rows
        .map(
          (row) => LessonPhrase(
            id: row['id'] as int,
            lessonId: row['lesson_id'] as int,
            text: row['phrase_text'] as String,
            imagePath: row['image_path'] as String?,
          ),
        )
        .toList();
  }

  Future<LessonPhrase?> addLessonPhrase({
    required int teacherUserId,
    required int lessonId,
    required String text,
    String? imagePath,
  }) async {
    if (!await _teacherOwnsLesson(teacherUserId, lessonId)) return null;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final db = await _dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert('lesson_phrases', {
      'lesson_id': lessonId,
      'phrase_text': trimmed,
      'image_path': imagePath,
      'sort_order': now,
      'created_at': now,
    });
    return LessonPhrase(
      id: id,
      lessonId: lessonId,
      text: trimmed,
      imagePath: imagePath,
    );
  }

  Future<bool> deleteLessonPhrase({
    required int teacherUserId,
    required int phraseId,
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT lp.id
      FROM lesson_phrases lp
      INNER JOIN class_lessons cl ON cl.id = lp.lesson_id
      INNER JOIN teacher_classes tc ON tc.id = cl.class_id
      WHERE lp.id = ? AND tc.teacher_user_id = ?
      LIMIT 1
    ''', [phraseId, teacherUserId]);
    if (rows.isEmpty) return false;
    await db.delete('lesson_phrases', where: 'id = ?', whereArgs: [phraseId]);
    return true;
  }

  List<(ParentAlertType, String, String, Duration, bool)> _filipinoNotificationSamples(
    String child,
  ) {
    return [
      (
        ParentAlertType.teacherAlert,
        'Alert mula sa guro — $child',
        'Pinadalhan ni Ms. Reyes ng urgent alert: kailangan ng $child ng magulang sa paaralan sa lalong madaling panahon.',
        const Duration(minutes: 18),
        false,
      ),
      (
        ParentAlertType.distress,
        'Maaaring kailangan ng $child ng pagpapakalma',
        'Naitala ng TapTalk ang paulit-ulit na distress phrases. Maaaring upset o nahihirapan ang $child.',
        const Duration(hours: 2, minutes: 5),
        false,
      ),
      (
        ParentAlertType.needsAttention,
        'Kailangan ng atensyon si $child',
        'Ginamit ni $child ang urgent phrases nang maraming beses sa maikling panahon. Pakitingnan kapag pwede.',
        const Duration(hours: 5, minutes: 40),
        true,
      ),
      (
        ParentAlertType.schoolNeeded,
        'Follow-up sa paaralan para kay $child',
        'Napansin ng guro na nahirapan si $child pagkatapos ng break. Maaaring makatulong ang pagdalo o tawag.',
        const Duration(days: 1, hours: 3),
        true,
      ),
      (
        ParentAlertType.teacherAlert,
        'Hiniling ang suporta sa silid-aralan',
        'Alert ng guro: na-overwhelm si $child sa group work at maaaring kailangan ng suporta ng magulang.',
        const Duration(days: 2, hours: 10),
        true,
      ),
      (
        ParentAlertType.distress,
        'Mataas na distress signals',
        'Maraming “I feel sad” at help phrases ang ginamit ngayon. Isaalang-alang ang calm check-in kay $child.',
        const Duration(days: 4, hours: 6),
        true,
      ),
    ];
  }
}
