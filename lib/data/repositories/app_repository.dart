import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/constants/tts_speed_options.dart';
import '../../services/cloud_notification_backend.dart';
import '../database/database_helper.dart';
import '../models/vocabulary_growth_summary.dart';
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
import '../models/child_lesson_progress.dart';
import '../models/phrase_usage_stat.dart';
import '../models/class_lesson.dart';
import '../models/lesson_phrase.dart';
import '../models/teacher_alert_result.dart';
import '../models/teacher_class_student.dart';
import '../models/user_model.dart';

class AppRepository {
  AppRepository(this._dbHelper);

  final DatabaseHelper _dbHelper;

  /// Preserves user typing; only trims outer whitespace.
  static String storedUserText(String text) => text.trim();

  static bool sameStoredText(String a, String b) => a.trim() == b.trim();

  static bool sameLessonTitle(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

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

  /// True when [categoryKey] (raw or normalized) refers to a class lesson bucket.
  static bool isLessonCategoryKey(String categoryKey) {
    if (HistoryModel.decodeLessonCategoryKey(categoryKey) != null) {
      return true;
    }
    final trimmed = categoryKey.trim().toLowerCase();
    if (trimmed == 'lesson') return true;
    if (trimmed.startsWith(HistoryModel.lessonCategoryPrefix)) return true;
    final normalized = normalizeCategoryKey(categoryKey);
    if (normalized == 'lesson') return true;
    // Encoded keys like lesson:::Class:::Title become lesson_class_title.
    if (normalized.startsWith('lesson_')) return true;
    return false;
  }

  /// True for learner "For Me" categories — excludes class/lesson phrase buckets.
  static bool isPersonalCategoryKey(String categoryKey) {
    return !isLessonCategoryKey(categoryKey);
  }

  static String monitoringCategoryKey({
    required String categoryKey,
    String? className,
    String? lessonTitle,
  }) {
    return normalizeCategoryKey(
      resolveHistoryCategoryKey(
        categoryKey: categoryKey,
        className: className,
        lessonTitle: lessonTitle,
      ),
    );
  }

  static bool isLessonHistoryRow({
    required String categoryKey,
    String? className,
    String? lessonTitle,
  }) {
    final trimmedClass = className?.trim();
    final trimmedLesson = lessonTitle?.trim();
    if (trimmedClass != null &&
        trimmedClass.isNotEmpty &&
        trimmedLesson != null &&
        trimmedLesson.isNotEmpty) {
      return true;
    }
    return isLessonCategoryKey(categoryKey);
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

  Future<int> ensureUserStubFromFirebase({
    required String firebaseUid,
    required String role,
    required String displayName,
    String? profileCode,
  }) async {
    final existing = await findUserByFirebaseUid(firebaseUid);
    if (existing != null) {
      if (role == 'learner' &&
          profileCode != null &&
          profileCode.trim().isNotEmpty) {
        await updateUserSettings(existing.id, profileCode: profileCode);
      }
      return existing.id;
    }

    final db = await _dbHelper.database;
    final settings = <String, dynamic>{
      'language': 'English',
      'tts_speed': TtsSpeedOptions.defaultSpeed,
    };
    if (role == 'learner' &&
        profileCode != null &&
        profileCode.trim().isNotEmpty) {
      settings['profile_code'] = normalizeProfileCode(profileCode);
    }
    final stubEmail = '${firebaseUid.substring(0, 8)}@taptalk.stub';

    final id = await db.insert('users', {
      'email': stubEmail,
      'password_hash': '',
      'full_name': displayName.trim().isEmpty ? role : displayName.trim(),
      'role': role,
      'theme': role == 'learner' ? null : 'mint_green',
      'settings_json': jsonEncode(settings),
      'firebase_uid': firebaseUid.trim(),
    });

    if (role == 'learner' || role == 'parent') {
      await seedLearnerData(id);
    }
    return id;
  }

  Future<UserModel> provisionLocalUserFromCloud({
    required String email,
    required String password,
    required String firebaseUid,
    required RemoteUserProfile profile,
  }) async {
    final byUid = await findUserByFirebaseUid(firebaseUid);
    if (byUid != null) return byUid;

    final db = await _dbHelper.database;
    final settings = <String, dynamic>{
      'language': 'English',
      'tts_speed': TtsSpeedOptions.defaultSpeed,
    };
    if (profile.profileCode != null && profile.profileCode!.trim().isNotEmpty) {
      settings['profile_code'] = normalizeProfileCode(profile.profileCode!);
    }

    final id = await db.insert('users', {
      'email': email.trim().toLowerCase(),
      'password_hash': hashPassword(password),
      'full_name': profile.fullName.trim().isEmpty
          ? email.trim()
          : profile.fullName.trim(),
      'role': profile.role,
      'theme': profile.role == 'learner'
          ? profile.themeKey
          : (profile.themeKey ?? 'mint_green'),
      'settings_json': jsonEncode(settings),
      'firebase_uid': firebaseUid.trim(),
    });

    final user = (await findUserById(id))!;
    if (profile.role == 'learner' || profile.role == 'parent') {
      await seedLearnerData(user.id);
    }
    return user;
  }

  Future<Map<String, Object?>?> importRemoteTeacherClassForEnrollment(
    RemoteTeacherClass remote,
  ) async {
    final code = normalizeClassCode(remote.classCode);
    if (!isValidClassCodeFormat(code)) return null;

    final existing = await findClassByCode(code);
    if (existing != null) return existing;

    final teacherId = await ensureUserStubFromFirebase(
      firebaseUid: remote.teacherFirebaseUid,
      role: 'teacher',
      displayName: 'Teacher',
    );

    final db = await _dbHelper.database;
    await db.insert('teacher_classes', {
      'teacher_user_id': teacherId,
      'class_name':
          remote.className.trim().isEmpty ? 'Class' : remote.className.trim(),
      'class_code': code,
      'created_at': remote.createdAt.millisecondsSinceEpoch,
    });
    return findClassByCode(code);
  }

  Future<UserModel> ensureLearnerFromRemoteProfile(
    RemoteLearnerProfile remote,
  ) async {
    final existing = await findUserByFirebaseUid(remote.learnerFirebaseUid);
    if (existing != null) {
      if (remote.profileCode.trim().isNotEmpty) {
        await updateUserSettings(
          existing.id,
          profileCode: normalizeProfileCode(remote.profileCode),
        );
      }
      return existing;
    }

    final id = await ensureUserStubFromFirebase(
      firebaseUid: remote.learnerFirebaseUid,
      role: 'learner',
      displayName:
          remote.learnerName.trim().isEmpty ? 'Learner' : remote.learnerName,
      profileCode: remote.profileCode,
    );
    return (await findUserById(id))!;
  }

  Future<void> mergeRemoteParentChildLinks({
    required int parentUserId,
    required List<RemoteParentChildLink> links,
  }) async {
    if (links.isEmpty) return;
    for (final link in links) {
      final learnerUid = link.learnerFirebaseUid.trim();
      if (learnerUid.isEmpty) continue;

      UserModel? learner = await findUserByFirebaseUid(learnerUid);

      if (learner == null && link.learnerUserId > 0) {
        final local = await findUserById(link.learnerUserId);
        if (local != null && local.isLearner) {
          learner = local;
        }
      }

      if (learner == null && link.learnerProfileCode.trim().isNotEmpty) {
        final byCode = await findLearnerByProfileCode(link.learnerProfileCode);
        if (byCode != null && await isChildLinked(parentUserId, byCode.id)) {
          learner = byCode;
        }
      }

      learner ??= await ensureLearnerFromRemoteProfile(
        RemoteLearnerProfile(
          learnerFirebaseUid: learnerUid,
          learnerName: link.learnerName,
          profileCode: link.learnerProfileCode,
          learnerUserId: link.learnerUserId,
        ),
      );

      final currentUid = learner.firebaseUid?.trim() ?? '';
      if (currentUid != learnerUid) {
        await linkFirebaseUid(learner.id, learnerUid);
      }

      if (!await isChildLinked(parentUserId, learner.id)) {
        await linkParentToChild(parentUserId, learner.id);
      }
    }
  }

  /// Earliest parent link or class enrollment — same tracking window for all roles.
  Future<DateTime> getEarliestLearnerTrackingDate(int learnerUserId) async {
    final db = await _dbHelper.database;
    final timestamps = <int>[];

    final linkRows = await db.query(
      'parent_children',
      columns: ['linked_at'],
      where: 'learner_user_id = ?',
      whereArgs: [learnerUserId],
    );
    for (final row in linkRows) {
      timestamps.add(row['linked_at'] as int);
    }

    final enrollRows = await db.query(
      'class_enrollments',
      columns: ['enrolled_at'],
      where: 'learner_user_id = ?',
      whereArgs: [learnerUserId],
    );
    for (final row in enrollRows) {
      timestamps.add(row['enrolled_at'] as int);
    }

    if (timestamps.isEmpty) {
      return DateTime.now().subtract(const Duration(days: 365 * 3));
    }
    return DateTime.fromMillisecondsSinceEpoch(
      timestamps.reduce((a, b) => a < b ? a : b),
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
      'tts_speed': TtsSpeedOptions.defaultSpeed,
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
    final cleaned = normalizeEmergencyContacts(contacts);
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
      return {
        'language': 'English',
        'tts_speed': TtsSpeedOptions.defaultSpeed,
      };
    }
    return jsonDecode(rows.first['settings_json'] as String) as Map<String, dynamic>;
  }

  Future<List<String>> getEmergencyContactsForLearner(int learnerUserId) async {
    final user = await findUserById(learnerUserId);
    if (user == null || !user.isLearner) return const [];
    final settings = await getUserSettings(learnerUserId);
    final contacts = settings['emergency_contacts'];
    if (contacts is! List) return const [];
    return normalizeEmergencyContacts(
      contacts.whereType<String>().toList(),
    );
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

  Future<void> mergeRemoteLearnerCategories({
    required int learnerUserId,
    required List<RemoteLearnerCategory> remoteCategories,
  }) async {
    if (remoteCategories.isEmpty) return;
    final db = await _dbHelper.database;
    for (final remote in remoteCategories) {
      final key = normalizeCategoryKey(remote.key);
      if (key.isEmpty) continue;
      final existing = await db.query(
        'categories',
        where: 'user_id = ? AND category_key = ?',
        whereArgs: [learnerUserId, key],
        limit: 1,
      );
      if (existing.isNotEmpty) continue;
      await db.insert('categories', {
        'user_id': learnerUserId,
        'category_key': key,
        'category_name':
            remote.name.trim().isEmpty ? key : remote.name.trim(),
        'icon_key': remote.iconKey.trim().isEmpty ? 'custom' : remote.iconKey,
      });
    }
  }

  static List<CategoryVocabularySlice> buildCategorySlicesForAllCategories({
    required List<CategoryModel> categories,
    required List<CategoryVocabularySlice> usageSlices,
  }) {
    final usageByKey = <String, CategoryVocabularySlice>{};
    for (final slice in usageSlices) {
      if (!isPersonalCategoryKey(slice.categoryKey)) continue;
      final key = normalizeCategoryKey(slice.categoryKey);
      usageByKey[key] = slice;
    }

    final results = <CategoryVocabularySlice>[];
    final seen = <String>{};
    for (final category in categories) {
      if (!isPersonalCategoryKey(category.key)) continue;
      final key = normalizeCategoryKey(category.key);
      if (key.isEmpty || !seen.add(key)) continue;
      final usage = usageByKey[key];
      results.add(
        CategoryVocabularySlice(
          categoryKey: category.key,
          wordCount: usage?.wordCount ?? 0,
          usageCount: usage?.usageCount ?? 0,
        ),
      );
    }
    for (final slice in usageSlices) {
      if (!isPersonalCategoryKey(slice.categoryKey)) continue;
      final key = normalizeCategoryKey(slice.categoryKey);
      if (key.isEmpty || !seen.add(key)) continue;
      results.add(slice);
    }
    return results;
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
    final now = DateTime.now();
    final id = await db.insert('phrases', {
      'user_id': userId,
      'phrase_text': text.trim(),
      'category_key': categoryKey,
      'image_path': imagePath,
      'is_builtin': 0,
      'is_active': 1,
      'created_at': now.millisecondsSinceEpoch,
    });
    return PhraseModel(
      id: id,
      userId: userId,
      text: text.trim(),
      categoryKey: categoryKey,
      imagePath: imagePath,
      createdAt: now,
    );
  }

  /// Learner-added phrases (not app defaults) for vocabulary growth tracking.
  Future<List<PhraseFirstUse>> getCustomPhraseAdditions({
    required int learnerUserId,
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'phrases',
      columns: ['phrase_text', 'category_key', 'created_at'],
      where: 'user_id = ? AND is_builtin = 0 AND is_active = 1 AND created_at IS NOT NULL',
      whereArgs: [learnerUserId],
      orderBy: 'created_at ASC',
    );
    final merged = <String, PhraseFirstUse>{};
    for (final row in rows) {
      final stored = storedUserText(row['phrase_text'] as String);
      final categoryKey = normalizeCategoryKey(row['category_key'] as String);
      if (!isPersonalCategoryKey(categoryKey)) continue;
      final createdAt = DateTime.fromMillisecondsSinceEpoch(
        row['created_at'] as int,
      );
      final mergeKey = '$categoryKey|$stored';
      final existing = merged[mergeKey];
      if (existing == null || createdAt.isBefore(existing.firstUsedAt)) {
        merged[mergeKey] = PhraseFirstUse(
          text: stored,
          categoryKey: categoryKey,
          firstUsedAt: createdAt,
        );
      }
    }
    return merged.values.toList()
      ..sort((a, b) => a.firstUsedAt.compareTo(b.firstUsedAt));
  }

  Future<List<RemoteLearnerCustomPhrase>> getCustomPhrasesForCloudSync(
    int learnerUserId,
  ) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'phrases',
      columns: ['phrase_text', 'category_key', 'created_at'],
      where:
          'user_id = ? AND is_builtin = 0 AND is_active = 1 AND created_at IS NOT NULL',
      whereArgs: [learnerUserId],
      orderBy: 'created_at ASC',
    );
    return rows
        .map((row) {
          final createdRaw = row['created_at'];
          if (createdRaw is! int) return null;
          return RemoteLearnerCustomPhrase(
            phraseText: storedUserText(row['phrase_text'] as String),
            categoryKey: normalizeCategoryKey(row['category_key'] as String),
            createdAt: DateTime.fromMillisecondsSinceEpoch(createdRaw),
          );
        })
        .whereType<RemoteLearnerCustomPhrase>()
        .where((p) => p.phraseText.isNotEmpty && p.categoryKey.isNotEmpty)
        .toList();
  }

  Future<void> mergeRemoteLearnerCustomPhrases({
    required int learnerUserId,
    required List<RemoteLearnerCustomPhrase> phrases,
  }) async {
    if (phrases.isEmpty) return;
    final db = await _dbHelper.database;
    for (final remote in phrases) {
      final text = remote.phraseText.trim();
      final categoryKey = normalizeCategoryKey(remote.categoryKey);
      if (text.isEmpty || categoryKey.isEmpty) continue;
      if (!isPersonalCategoryKey(categoryKey)) continue;
      final createdAtMs = remote.createdAt.millisecondsSinceEpoch;
      final existing = await db.query(
        'phrases',
        where:
            'user_id = ? AND phrase_text = ? AND category_key = ? AND is_builtin = 0',
        whereArgs: [learnerUserId, text, categoryKey],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final currentCreated = existing.first['created_at'] as int?;
        if (currentCreated == null || createdAtMs < currentCreated) {
          await db.update(
            'phrases',
            {'created_at': createdAtMs},
            where: 'id = ?',
            whereArgs: [existing.first['id']],
          );
        }
        continue;
      }
      await db.insert(
        'phrases',
        {
          'user_id': learnerUserId,
          'phrase_text': text,
          'category_key': categoryKey,
          'is_builtin': 0,
          'is_active': 1,
          'created_at': createdAtMs,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
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

  Future<bool> updatePhrase({
    required int userId,
    required int phraseId,
    required String text,
    String? imagePath,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    final db = await _dbHelper.database;
    final updated = await db.update(
      'phrases',
      {
        'phrase_text': trimmed,
        'image_path': imagePath,
      },
      where: 'id = ? AND user_id = ? AND is_builtin = 0',
      whereArgs: [phraseId, userId],
    );
    if (updated <= 0) return false;

    // Keep favorites (if any) consistent for this phrase.
    await db.update(
      'favorites',
      {
        'phrase_text': trimmed,
        'image_path': imagePath,
      },
      where: 'user_id = ? AND phrase_id = ?',
      whereArgs: [userId, phraseId],
    );
    return true;
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

  static String resolveHistoryCategoryKey({
    required String categoryKey,
    String? className,
    String? lessonTitle,
  }) {
    final trimmedClass = className?.trim();
    final trimmedLesson = lessonTitle?.trim();
    if (trimmedClass != null &&
        trimmedClass.isNotEmpty &&
        trimmedLesson != null &&
        trimmedLesson.isNotEmpty) {
      return HistoryModel.encodeLessonCategoryKey(
        className: trimmedClass,
        lessonTitle: trimmedLesson,
      );
    }
    return categoryKey;
  }

  Future<int?> addHistory({
    required int userId,
    required String text,
    required String categoryKey,
    String? className,
    String? lessonTitle,
    DateTime? createdAt,
  }) async {
    if (text.trim().isEmpty) return null;
    final db = await _dbHelper.database;
    final trimmedClass = className?.trim();
    final trimmedLesson = lessonTitle?.trim();
    final hasLessonContext = trimmedClass != null &&
        trimmedClass.isNotEmpty &&
        trimmedLesson != null &&
        trimmedLesson.isNotEmpty;
    final effectiveCategoryKey = resolveHistoryCategoryKey(
      categoryKey: categoryKey,
      className: className,
      lessonTitle: lessonTitle,
    );
    final row = <String, Object?>{
      'user_id': userId,
      'phrase_text': text.trim(),
      'category_key': effectiveCategoryKey,
      'created_at': (createdAt ?? DateTime.now()).millisecondsSinceEpoch,
    };
    if (hasLessonContext) {
      row['class_name'] = trimmedClass;
      row['lesson_title'] = trimmedLesson;
    }
    try {
      return await db.insert('history', row);
    } on DatabaseException {
      row.remove('class_name');
      row.remove('lesson_title');
      return await db.insert('history', row);
    }
  }

  /// History rows not yet uploaded to Firestore for parent/teacher monitoring.
  Future<List<HistoryModel>> getUnsyncedHistory(int userId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'history',
      where: 'user_id = ? AND remote_sync_key IS NULL',
      whereArgs: [userId],
      orderBy: 'created_at ASC',
    );
    return rows.map(HistoryModel.fromMap).toList();
  }

  Future<void> markHistoryCloudSynced({
    required int historyId,
    required String syncKey,
  }) async {
    final db = await _dbHelper.database;
    await db.update(
      'history',
      {'remote_sync_key': syncKey},
      where: 'id = ?',
      whereArgs: [historyId],
    );
  }

  static String syncKeyForHistoryItem(HistoryModel item) {
    return remoteActivitySyncKey(
      createdAt: item.createdAt,
      phraseText: item.text,
      categoryKey: resolveHistoryCategoryKey(
        categoryKey: item.categoryKey,
        className: item.className,
        lessonTitle: item.lessonTitle,
      ),
    );
  }

  static String remoteActivitySyncKey({
    required DateTime createdAt,
    required String phraseText,
    required String categoryKey,
  }) {
    final ts = createdAt.toUtc().millisecondsSinceEpoch;
    final textKey = phraseText.trim().hashCode;
    return '${ts}_${textKey}_${categoryKey.hashCode}';
  }

  /// Persists cloud learner activities locally so parent/teacher monitoring
  /// works offline after at least one online sync.
  Future<void> mergeRemoteLearnerActivities({
    required int learnerUserId,
    required List<RemoteLearnerActivity> activities,
  }) async {
    if (activities.isEmpty) return;
    final db = await _dbHelper.database;
    var batch = db.batch();
    var pending = 0;

    Future<void> flush() async {
      if (pending == 0) return;
      await batch.commit(noResult: true);
      batch = db.batch();
      pending = 0;
    }

    for (final activity in activities) {
      final text = activity.phraseText.trim();
      if (text.isEmpty) continue;
      final trimmedClass = activity.className?.trim();
      final trimmedLesson = activity.lessonTitle?.trim();
      final hasLessonContext = trimmedClass != null &&
          trimmedClass.isNotEmpty &&
          trimmedLesson != null &&
          trimmedLesson.isNotEmpty;
      final effectiveCategoryKey = resolveHistoryCategoryKey(
        categoryKey: activity.categoryKey,
        className: activity.className,
        lessonTitle: activity.lessonTitle,
      );
      final createdAtMs = activity.createdAt.millisecondsSinceEpoch;
      final syncKey = remoteActivitySyncKey(
        createdAt: activity.createdAt,
        phraseText: text,
        categoryKey: effectiveCategoryKey,
      );
      final row = <String, Object?>{
        'user_id': learnerUserId,
        'phrase_text': text,
        'category_key': effectiveCategoryKey,
        'created_at': createdAtMs,
        'remote_sync_key': syncKey,
      };
      if (hasLessonContext) {
        row['class_name'] = trimmedClass;
        row['lesson_title'] = trimmedLesson;
      }
      batch.insert(
        'history',
        row,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      pending++;
      if (pending >= 200) {
        await flush();
      }
    }
    await flush();
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
      SELECT phrase_text, category_key, class_name, lesson_title,
             MIN(created_at) AS first_used_at
      FROM history
      WHERE user_id = ?
      GROUP BY phrase_text, category_key, class_name, lesson_title
    ''', [learnerUserId]);

    final merged = <String, PhraseFirstUse>{};
    for (final row in rows) {
      final stored = storedUserText(row['phrase_text'] as String);
      final categoryKey = monitoringCategoryKey(
        categoryKey: row['category_key'] as String,
        className: row['class_name'] as String?,
        lessonTitle: row['lesson_title'] as String?,
      );
      if (!isPersonalCategoryKey(categoryKey)) continue;
      final firstUsedAt = DateTime.fromMillisecondsSinceEpoch(
        row['first_used_at'] as int,
      );
      final mergeKey = '$categoryKey|$stored';
      final existing = merged[mergeKey];
      if (existing == null || firstUsedAt.isBefore(existing.firstUsedAt)) {
        merged[mergeKey] = PhraseFirstUse(
          text: stored,
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
      SELECT phrase_text, category_key, class_name, lesson_title,
             COUNT(*) AS usage_count
      FROM history
      WHERE user_id = ?
        AND created_at >= ?
        AND created_at < ?
      GROUP BY phrase_text, category_key, class_name, lesson_title
      ORDER BY usage_count DESC, phrase_text ASC
    ''', [
      learnerUserId,
      rangeStart.millisecondsSinceEpoch,
      rangeEnd.millisecondsSinceEpoch,
    ]);
    final merged = <String, PhraseUsageStat>{};
    for (final row in rows) {
      final stored = storedUserText(row['phrase_text'] as String);
      final categoryKey = monitoringCategoryKey(
        categoryKey: row['category_key'] as String,
        className: row['class_name'] as String?,
        lessonTitle: row['lesson_title'] as String?,
      );
      if (!isPersonalCategoryKey(categoryKey)) continue;
      final count = row['usage_count'] as int;
      final mergeKey = '$categoryKey|$stored';
      final existing = merged[mergeKey];
      if (existing == null) {
        merged[mergeKey] = PhraseUsageStat(
          text: stored,
          categoryKey: categoryKey,
          count: count,
        );
      } else {
        merged[mergeKey] = PhraseUsageStat(
          text: stored,
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

  Future<List<ChildLessonProgressEntry>> getChildLessonProgress({
    required int learnerUserId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    List<RemoteLearnerActivity> cloudActivities = const [],
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'history',
      where: 'user_id = ? AND created_at >= ? AND created_at < ?',
      whereArgs: [
        learnerUserId,
        rangeStart.millisecondsSinceEpoch,
        rangeEnd.millisecondsSinceEpoch,
      ],
      orderBy: 'created_at DESC',
    );

    final aggregate = <String, _LessonProgressAgg>{};
    void absorbLessonActivity({
      required String text,
      required String categoryKey,
      required DateTime createdAt,
      String? className,
      String? lessonTitle,
    }) {
      final item = HistoryModel(
        id: 0,
        userId: learnerUserId,
        text: text,
        categoryKey: categoryKey,
        createdAt: createdAt,
        className: className,
        lessonTitle: lessonTitle,
      );
      if (!item.isLessonEntry) return;
      final ctx = item.lessonContext!;
      final key = '${ctx.className}:::${ctx.lessonTitle}';
      final agg = aggregate.putIfAbsent(
        key,
        () => _LessonProgressAgg(
          className: ctx.className,
          lessonTitle: ctx.lessonTitle,
        ),
      );
      agg.totalInteractions++;
      if (agg.lastAccessed == null || createdAt.isAfter(agg.lastAccessed!)) {
        agg.lastAccessed = createdAt;
      }
      final stored = storedUserText(text);
      if (!sameStoredText(stored, ctx.lessonTitle)) {
        agg.practicedPhrases.add(stored);
      }
    }

    for (final row in rows) {
      final item = HistoryModel.fromMap(row);
      if (!item.isLessonEntry) continue;
      final ctx = item.lessonContext!;
      final key = '${ctx.className}:::${ctx.lessonTitle}';
      final agg = aggregate.putIfAbsent(
        key,
        () => _LessonProgressAgg(
          className: ctx.className,
          lessonTitle: ctx.lessonTitle,
        ),
      );
      agg.totalInteractions++;
      if (agg.lastAccessed == null ||
          item.createdAt.isAfter(agg.lastAccessed!)) {
        agg.lastAccessed = item.createdAt;
      }
      final stored = storedUserText(item.text);
      if (!sameStoredText(stored, ctx.lessonTitle)) {
        agg.practicedPhrases.add(stored);
      }
    }

    for (final activity in cloudActivities) {
      absorbLessonActivity(
        text: activity.phraseText,
        categoryKey: activity.categoryKey,
        createdAt: activity.createdAt,
        className: activity.className,
        lessonTitle: activity.lessonTitle,
      );
    }

    final results = <ChildLessonProgressEntry>[];
    for (final agg in aggregate.values) {
      final totalPhrases = await _lessonPhraseCountForTitle(
        className: agg.className,
        lessonTitle: agg.lessonTitle,
      );
      results.add(
        ChildLessonProgressEntry(
          className: agg.className,
          lessonTitle: agg.lessonTitle,
          practicedPhrases: agg.practicedPhrases.length,
          totalInteractions: agg.totalInteractions,
          lastAccessed: agg.lastAccessed ?? rangeStart,
          totalPhrases: totalPhrases,
        ),
      );
    }

    results.sort((a, b) {
      final byClass = a.className.compareTo(b.className);
      if (byClass != 0) return byClass;
      final aTime = a.lastAccessed ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastAccessed ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return results;
  }

  Future<int?> _lessonPhraseCountForTitle({
    required String className,
    required String lessonTitle,
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT
        (SELECT COUNT(*) FROM lesson_phrases lp WHERE lp.lesson_id = cl.id) AS phrase_count
      FROM class_lessons cl
      INNER JOIN teacher_classes tc ON tc.id = cl.class_id
      WHERE tc.class_name = ? AND cl.title = ?
      LIMIT 1
    ''', [className, lessonTitle]);
    if (rows.isEmpty) return null;
    return rows.first['phrase_count'] as int?;
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

  /// Canonical key for deduping Philippine phone numbers (09…, 63…, +63…).
  static String? emergencyPhoneKey(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^\d+]'), '').trim();
    if (cleaned.isEmpty) return null;
    if (cleaned.startsWith('+')) {
      return RegExp(r'^\+\d{10,15}$').hasMatch(cleaned) ? cleaned : null;
    }
    if (RegExp(r'^0\d{10}$').hasMatch(cleaned)) {
      return '+63${cleaned.substring(1)}';
    }
    if (RegExp(r'^63\d{10}$').hasMatch(cleaned)) {
      return '+$cleaned';
    }
    if (RegExp(r'^\d{10,15}$').hasMatch(cleaned)) {
      return '+$cleaned';
    }
    return null;
  }

  /// Up to two unique, non-empty emergency numbers in learner-entered order.
  static List<String> normalizeEmergencyContacts(List<String> contacts) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in contacts) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      final key = emergencyPhoneKey(trimmed);
      if (key == null || seen.contains(key)) continue;
      seen.add(key);
      out.add(trimmed);
      if (out.length >= 2) break;
    }
    return out;
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

  Future<bool> updateTeacherClassName({
    required int teacherUserId,
    required int classId,
    required String className,
  }) async {
    final trimmed = className.trim();
    if (trimmed.isEmpty) return false;
    final db = await _dbHelper.database;
    final updated = await db.update(
      'teacher_classes',
      {'class_name': trimmed},
      where: 'id = ? AND teacher_user_id = ?',
      whereArgs: [classId, teacherUserId],
    );
    return updated > 0;
  }

  Future<int> countStudentsInClass(int classId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM class_enrollments WHERE class_id = ?',
      [classId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Distinct enrolled learners across the given class IDs.
  Future<int> countStudentsInClasses(List<int> classIds) async {
    if (classIds.isEmpty) return 0;
    final db = await _dbHelper.database;
    final placeholders = List.filled(classIds.length, '?').join(', ');
    final result = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT learner_user_id) AS c
      FROM class_enrollments
      WHERE class_id IN ($placeholders)
      ''',
      classIds,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Distinct enrolled learners across all of a teacher's existing classes.
  Future<int> countEnrolledStudentsForTeacher(int teacherUserId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT ce.learner_user_id) AS c
      FROM class_enrollments ce
      INNER JOIN teacher_classes tc ON tc.id = ce.class_id
      WHERE tc.teacher_user_id = ?
    ''', [teacherUserId]);
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

  /// Matches a locally enrolled learner when cloud enrollment carries a Firebase UID.
  Future<UserModel?> findEnrolledLearnerInClassByName({
    required int classId,
    required String fullName,
  }) async {
    final normalized = fullName.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT u.id
      FROM class_enrollments ce
      INNER JOIN users u ON u.id = ce.learner_user_id
      WHERE ce.class_id = ?
        AND LOWER(TRIM(u.full_name)) = ?
      LIMIT 1
    ''', [classId, normalized]);
    if (rows.isEmpty) return null;
    return findUserById(rows.first['id'] as int);
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
    Set<String> skipClassCodes = const {},
  }) async {
    if (remoteClasses.isEmpty) return;
    final db = await _dbHelper.database;
    for (final remote in remoteClasses) {
      final code = normalizeClassCode(remote.classCode);
      if (!isValidClassCodeFormat(code)) continue;
      if (skipClassCodes.contains(code)) continue;
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
    final remoteKeys = <String>{};
    for (final enrollment in enrollments) {
      final code = normalizeClassCode(enrollment.classCode);
      final learnerUid = enrollment.learnerFirebaseUid.trim();
      if (!isValidClassCodeFormat(code) || learnerUid.isEmpty) continue;
      remoteKeys.add('${code}_$learnerUid');
    }

    for (final enrollment in enrollments) {
      final code = normalizeClassCode(enrollment.classCode);
      if (!isValidClassCodeFormat(code)) continue;
      final classRow = await findClassByCode(code);
      if (classRow == null) continue;
      if ((classRow['teacher_user_id'] as int?) != teacherUserId) continue;
      final classId = classRow['id'] as int;
      final learnerUid = enrollment.learnerFirebaseUid.trim();
      if (learnerUid.isEmpty) continue;
      var learner = await findUserByFirebaseUid(learnerUid);
      if (learner == null) {
        final enrolledName = enrollment.learnerName.trim();
        if (enrolledName.isNotEmpty) {
          learner = await findEnrolledLearnerInClassByName(
            classId: classId,
            fullName: enrolledName,
          );
        }
      }
      if (learner == null) {
        final stubId = await ensureUserStubFromFirebase(
          firebaseUid: learnerUid,
          role: 'learner',
          displayName: enrollment.learnerName.trim().isEmpty
              ? 'Learner'
              : enrollment.learnerName.trim(),
        );
        learner = await findUserById(stubId);
      }
      if (learner == null) continue;
      final linkedUid = learner.firebaseUid?.trim() ?? '';
      if (linkedUid != learnerUid) {
        await linkFirebaseUid(learner.id, learnerUid);
      }
      if (!await isLearnerEnrolled(learner.id, classId)) {
        await enrollLearnerInClass(learner.id, classId);
      }
    }

    // Only prune when cloud returned enrollment rows. An empty snapshot usually
    // means sync is still in progress, not that every student left.
    if (remoteKeys.isNotEmpty) {
      await _pruneStaleEnrollmentsForTeacher(
        teacherUserId: teacherUserId,
        remoteEnrollmentKeys: remoteKeys,
      );
    }
  }

  Future<void> _pruneStaleEnrollmentsForTeacher({
    required int teacherUserId,
    required Set<String> remoteEnrollmentKeys,
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT
        ce.learner_user_id,
        ce.class_id,
        tc.class_code,
        u.firebase_uid
      FROM class_enrollments ce
      INNER JOIN teacher_classes tc ON tc.id = ce.class_id
      INNER JOIN users u ON u.id = ce.learner_user_id
      WHERE tc.teacher_user_id = ?
    ''', [teacherUserId]);

    for (final row in rows) {
      final firebaseUid = (row['firebase_uid'] as String?)?.trim() ?? '';
      if (firebaseUid.isEmpty) continue;
      final code = normalizeClassCode((row['class_code'] as String?) ?? '');
      if (!isValidClassCodeFormat(code)) continue;
      final key = '${code}_$firebaseUid';
      if (!remoteEnrollmentKeys.contains(key)) {
        await unenrollLearnerFromClass(
          row['learner_user_id'] as int,
          row['class_id'] as int,
        );
      }
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

  Future<List<ClassLesson>> getClassLessonsByClassId(int classId) async {
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

  Future<ChildLessonProgressEntry> getLessonProgressForLesson({
    required int learnerUserId,
    required String className,
    required String lessonTitle,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    List<RemoteLearnerActivity> cloudActivities = const [],
  }) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'history',
      where: 'user_id = ? AND created_at >= ? AND created_at < ?',
      whereArgs: [
        learnerUserId,
        rangeStart.millisecondsSinceEpoch,
        rangeEnd.millisecondsSinceEpoch,
      ],
      orderBy: 'created_at DESC',
    );

    final practiced = <String>{};
    var totalInteractions = 0;
    DateTime? lastAccessed;
    final lessonStored = lessonTitle.trim();
    final classCanonical = className.trim();

    void absorb({
      required String text,
      required String categoryKey,
      required DateTime createdAt,
      String? activityClassName,
      String? activityLessonTitle,
    }) {
      final item = HistoryModel(
        id: 0,
        userId: learnerUserId,
        text: text,
        categoryKey: categoryKey,
        createdAt: createdAt,
        className: activityClassName,
        lessonTitle: activityLessonTitle,
      );
      if (!item.isLessonEntry) return;
      final ctx = item.lessonContext!;
      if (ctx.className.trim() != classCanonical) return;
      if (!sameLessonTitle(ctx.lessonTitle, lessonStored)) {
        return;
      }
      totalInteractions++;
      if (lastAccessed == null || createdAt.isAfter(lastAccessed!)) {
        lastAccessed = createdAt;
      }
      final stored = storedUserText(text);
      if (!sameStoredText(stored, lessonStored)) {
        practiced.add(stored);
      }
    }

    for (final row in rows) {
      final item = HistoryModel.fromMap(row);
      if (!item.isLessonEntry) continue;
      absorb(
        text: item.text,
        categoryKey: item.categoryKey,
        createdAt: item.createdAt,
        activityClassName: item.className,
        activityLessonTitle: item.lessonTitle,
      );
    }

    for (final activity in cloudActivities) {
      absorb(
        text: activity.phraseText,
        categoryKey: activity.categoryKey,
        createdAt: activity.createdAt,
        activityClassName: activity.className,
        activityLessonTitle: activity.lessonTitle,
      );
    }

    final totalPhrases = await _lessonPhraseCountForTitle(
      className: className,
      lessonTitle: lessonTitle,
    );

    return ChildLessonProgressEntry(
      className: className,
      lessonTitle: lessonTitle,
      practicedPhrases: practiced.length,
      totalInteractions: totalInteractions,
      lastAccessed: lastAccessed,
      totalPhrases: totalPhrases,
    );
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
      SELECT
        pn.id,
        COALESCE(pn.class_id, tc.id) AS class_id,
        pn.child_name,
        pn.alert_type,
        pn.created_at,
        COALESCE(NULLIF(TRIM(pn.class_name), ''), tc.class_name, '') AS class_name
      FROM parent_notifications pn
      LEFT JOIN class_enrollments ce
        ON pn.teacher_user_id IS NULL
        AND pn.learner_user_id = ce.learner_user_id
      LEFT JOIN teacher_classes tc
        ON (
          (pn.class_id IS NOT NULL AND tc.id = pn.class_id)
          OR (pn.class_id IS NULL AND tc.id = ce.class_id)
        )
      WHERE pn.teacher_user_id = ?
         OR (pn.teacher_user_id IS NULL AND tc.teacher_user_id = ?)
      GROUP BY pn.id
      ORDER BY pn.created_at DESC
      LIMIT ?
    ''', [teacherUserId, teacherUserId, limit]);
    return rows
        .map(
          (row) => TeacherRecentAlert(
            id: row['id'] as int,
            classId: (row['class_id'] as int?) ?? 0,
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
    List<int>? parentUserIds,
  }) async {
    final authorized = await isLearnerInTeacherClass(
      teacherUserId: teacherUserId,
      learnerUserId: learnerUserId,
      classId: classId,
    );
    if (!authorized) {
      return const TeacherAlertResult(status: TeacherAlertStatus.notAuthorized);
    }

    final parentIds = parentUserIds ?? await getLinkedParentIds(learnerUserId);

    final db = await _dbHelper.database;
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    final notificationIds = <int>[];

    Future<int> insertAlertRow(int parentUserId) {
      return db.insert('parent_notifications', {
        'parent_user_id': parentUserId,
        'learner_user_id': learnerUserId,
        'teacher_user_id': teacherUserId,
        'class_id': classId,
        'class_name': className,
        'child_name': learnerName,
        'alert_type': alertType.name,
        'title': title,
        'body': body,
        'created_at': createdAt,
        'is_read': 0,
      });
    }

    if (parentIds.isEmpty) {
      notificationIds.add(await insertAlertRow(0));
      return TeacherAlertResult(
        status: TeacherAlertStatus.noLinkedParents,
        notificationIds: notificationIds,
      );
    }

    for (final parentId in parentIds) {
      notificationIds.add(await insertAlertRow(parentId));
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

  Future<int?> classIdForLesson(int lessonId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'class_lessons',
      columns: ['class_id'],
      where: 'id = ?',
      whereArgs: [lessonId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['class_id'] as int?;
  }

  Future<int?> classIdForLessonPhrase(int phraseId) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT cl.class_id
      FROM lesson_phrases lp
      INNER JOIN class_lessons cl ON cl.id = lp.lesson_id
      WHERE lp.id = ?
      LIMIT 1
    ''', [phraseId]);
    if (rows.isEmpty) return null;
    return rows.first['class_id'] as int?;
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

  static String? imagePathForCloudSync(String? imagePath) {
    if (imagePath == null || imagePath.trim().isEmpty) return null;
    final trimmed = imagePath.trim();
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('assets/')) {
      return trimmed;
    }
    return null;
  }

  Future<RemoteClassContent?> buildRemoteClassContent({
    required int teacherUserId,
    required int classId,
    required String classCode,
    required String className,
    required String teacherFirebaseUid,
  }) async {
    if (!await _teacherOwnsClass(teacherUserId, classId)) return null;
    final lessons = await getClassLessons(
      teacherUserId: teacherUserId,
      classId: classId,
    );
    final db = await _dbHelper.database;
    final remoteLessons = <RemoteClassLessonContent>[];
    for (final lesson in lessons) {
      final lessonRows = await db.query(
        'class_lessons',
        where: 'id = ?',
        whereArgs: [lesson.id],
        limit: 1,
      );
      if (lessonRows.isEmpty) continue;
      var lessonKey = lessonRows.first['cloud_lesson_key'] as String?;
      if (lessonKey == null || lessonKey.trim().isEmpty) {
        lessonKey = lesson.id.toString();
        await db.update(
          'class_lessons',
          {'cloud_lesson_key': lessonKey},
          where: 'id = ?',
          whereArgs: [lesson.id],
        );
      }
      final phraseRows = await db.query(
        'lesson_phrases',
        where: 'lesson_id = ?',
        whereArgs: [lesson.id],
        orderBy: 'sort_order ASC, id ASC',
      );
      final remotePhrases = <RemoteLessonPhraseContent>[];
      for (final phraseRow in phraseRows) {
        final phraseId = phraseRow['id'] as int;
        var phraseKey = phraseRow['cloud_phrase_key'] as String?;
        if (phraseKey == null || phraseKey.trim().isEmpty) {
          phraseKey = phraseId.toString();
          await db.update(
            'lesson_phrases',
            {'cloud_phrase_key': phraseKey},
            where: 'id = ?',
            whereArgs: [phraseId],
          );
        }
        remotePhrases.add(
          RemoteLessonPhraseContent(
            phraseKey: phraseKey,
            text: phraseRow['phrase_text'] as String,
            sortOrder: phraseRow['sort_order'] as int? ?? 0,
            imagePath: imagePathForCloudSync(phraseRow['image_path'] as String?),
          ),
        );
      }
      remoteLessons.add(
        RemoteClassLessonContent(
          lessonKey: lessonKey,
          title: lesson.title,
          sortOrder: lessonRows.first['sort_order'] as int? ?? 0,
          createdAt: lesson.createdAt,
          phrases: remotePhrases,
        ),
      );
    }
    return RemoteClassContent(
      classCode: normalizeClassCode(classCode),
      className: className.trim().isEmpty ? 'Class' : className.trim(),
      teacherFirebaseUid: teacherFirebaseUid.trim(),
      updatedAt: DateTime.now(),
      lessons: remoteLessons,
    );
  }

  Future<void> mergeRemoteClassContent({
    required int classId,
    required RemoteClassContent content,
  }) async {
    if (content.lessons.isEmpty) return;
    final db = await _dbHelper.database;
    final remoteLessonKeys = <String>{};

    for (final remoteLesson in content.lessons) {
      final lessonKey = remoteLesson.lessonKey.trim();
      if (lessonKey.isEmpty) continue;
      remoteLessonKeys.add(lessonKey);

      final existingLessonRows = await db.query(
        'class_lessons',
        where: 'class_id = ? AND cloud_lesson_key = ?',
        whereArgs: [classId, lessonKey],
        limit: 1,
      );

      int lessonId;
      if (existingLessonRows.isEmpty) {
        lessonId = await db.insert('class_lessons', {
          'class_id': classId,
          'title': storedUserText(remoteLesson.title),
          'created_at': remoteLesson.createdAt.millisecondsSinceEpoch,
          'sort_order': remoteLesson.sortOrder,
          'cloud_lesson_key': lessonKey,
        });
      } else {
        lessonId = existingLessonRows.first['id'] as int;
        await db.update(
          'class_lessons',
          {
            'title': storedUserText(remoteLesson.title),
            'sort_order': remoteLesson.sortOrder,
          },
          where: 'id = ?',
          whereArgs: [lessonId],
        );
      }

      final remotePhraseKeys = <String>{};
      for (final remotePhrase in remoteLesson.phrases) {
        final phraseKey = remotePhrase.phraseKey.trim();
        if (phraseKey.isEmpty) continue;
        remotePhraseKeys.add(phraseKey);
        final stored = storedUserText(remotePhrase.text);
        if (stored.isEmpty) continue;

        final existingPhraseRows = await db.query(
          'lesson_phrases',
          where: 'lesson_id = ? AND cloud_phrase_key = ?',
          whereArgs: [lessonId, phraseKey],
          limit: 1,
        );
        final imagePath = imagePathForCloudSync(remotePhrase.imagePath);
        if (existingPhraseRows.isEmpty) {
          await db.insert('lesson_phrases', {
            'lesson_id': lessonId,
            'phrase_text': stored,
            'image_path': imagePath,
            'sort_order': remotePhrase.sortOrder,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'cloud_phrase_key': phraseKey,
          });
        } else {
          await db.update(
            'lesson_phrases',
            {
              'phrase_text': stored,
              'image_path': imagePath,
              'sort_order': remotePhrase.sortOrder,
            },
            where: 'id = ?',
            whereArgs: [existingPhraseRows.first['id']],
          );
        }
      }

      final stalePhrases = await db.query(
        'lesson_phrases',
        where: 'lesson_id = ? AND cloud_phrase_key IS NOT NULL',
        whereArgs: [lessonId],
      );
      for (final row in stalePhrases) {
        final key = (row['cloud_phrase_key'] as String?)?.trim() ?? '';
        if (key.isNotEmpty && !remotePhraseKeys.contains(key)) {
          await db.delete(
            'lesson_phrases',
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
    }

    final staleLessons = await db.query(
      'class_lessons',
      where: 'class_id = ? AND cloud_lesson_key IS NOT NULL',
      whereArgs: [classId],
    );
    for (final row in staleLessons) {
      final key = (row['cloud_lesson_key'] as String?)?.trim() ?? '';
      if (key.isNotEmpty && !remoteLessonKeys.contains(key)) {
        final staleLessonId = row['id'] as int;
        await db.delete(
          'lesson_phrases',
          where: 'lesson_id = ?',
          whereArgs: [staleLessonId],
        );
        await db.delete(
          'class_lessons',
          where: 'id = ?',
          whereArgs: [staleLessonId],
        );
      }
    }
  }

  Future<ClassLesson?> createClassLesson({
    required int teacherUserId,
    required int classId,
    required String title,
  }) async {
    if (!await _teacherOwnsClass(teacherUserId, classId)) return null;
    final trimmed = storedUserText(title);
    if (trimmed.isEmpty) return null;
    final db = await _dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert('class_lessons', {
      'class_id': classId,
      'title': trimmed,
      'created_at': now,
      'sort_order': now,
    });
    await db.update(
      'class_lessons',
      {'cloud_lesson_key': id.toString()},
      where: 'id = ?',
      whereArgs: [id],
    );
    return ClassLesson(
      id: id,
      classId: classId,
      title: trimmed,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  Future<bool> updateClassLesson({
    required int teacherUserId,
    required int lessonId,
    required String title,
  }) async {
    if (!await _teacherOwnsLesson(teacherUserId, lessonId)) return false;
    final trimmed = storedUserText(title);
    if (trimmed.isEmpty) return false;
    final db = await _dbHelper.database;
    final updated = await db.update(
      'class_lessons',
      {'title': trimmed},
      where: 'id = ?',
      whereArgs: [lessonId],
    );
    return updated > 0;
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
    final trimmed = storedUserText(text);
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
    await db.update(
      'lesson_phrases',
      {'cloud_phrase_key': id.toString()},
      where: 'id = ?',
      whereArgs: [id],
    );
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

  Future<bool> updateLessonPhrase({
    required int teacherUserId,
    required int phraseId,
    required String text,
    String? imagePath,
  }) async {
    final trimmed = storedUserText(text);
    if (trimmed.isEmpty) return false;
    final db = await _dbHelper.database;

    // Verify ownership (phrase belongs to a lesson in teacher's class).
    final rows = await db.rawQuery('''
      SELECT lp.id
      FROM lesson_phrases lp
      INNER JOIN class_lessons cl ON cl.id = lp.lesson_id
      INNER JOIN teacher_classes tc ON tc.id = cl.class_id
      WHERE lp.id = ? AND tc.teacher_user_id = ?
      LIMIT 1
    ''', [phraseId, teacherUserId]);
    if (rows.isEmpty) return false;

    final updated = await db.update(
      'lesson_phrases',
      {
        'phrase_text': trimmed,
        'image_path': imagePath,
      },
      where: 'id = ?',
      whereArgs: [phraseId],
    );
    return updated > 0;
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

class _LessonProgressAgg {
  _LessonProgressAgg({
    required this.className,
    required this.lessonTitle,
  });

  final String className;
  final String lessonTitle;
  final practicedPhrases = <String>{};
  int totalInteractions = 0;
  DateTime? lastAccessed;
}
