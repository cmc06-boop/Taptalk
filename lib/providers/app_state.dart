import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../core/l10n/app_strings.dart';
import '../core/utils/auth_validation.dart';
import '../core/utils/phrase_image_storage.dart';
import '../core/l10n/content_localization.dart';
import '../data/models/category_model.dart';
import '../core/constants/app_spacing.dart';
import '../core/constants/monitoring_constants.dart';
export '../core/constants/child_usage_period.dart';
import '../core/constants/child_usage_period.dart';
import '../core/utils/session_usage_calculator.dart';
import '../core/utils/vocabulary_growth_calculator.dart';
import '../data/models/child_lesson_progress.dart';
import '../data/models/child_session_summary.dart';
import '../data/models/vocabulary_growth_summary.dart';
import '../core/constants/tts_speed_options.dart';
import '../core/theme/theme_tokens.dart';
import '../data/database/database_helper.dart';
import '../data/models/favorite_model.dart';
import '../data/models/history_model.dart';
import '../data/models/enrolled_class_model.dart';
import '../data/models/linked_child_model.dart';
import '../data/models/password_reset_outcome.dart';
import '../data/models/parent_notification.dart';
import '../data/models/teacher_recent_alert.dart';
import '../data/models/teacher_recent_lesson.dart';
import '../data/models/phrase_model.dart';
import '../data/models/phrase_usage_stat.dart';
import '../data/models/class_lesson.dart';
import '../data/models/lesson_phrase.dart';
import '../data/models/sms_alert_result.dart';
import '../data/models/teacher_alert_result.dart';
import '../data/models/teacher_class_student.dart';
import '../data/models/user_model.dart';
import '../data/repositories/app_repository.dart';
import '../services/cloud_notification_backend.dart';
import '../services/cloud_scope.dart';
import '../services/firebase_service.dart';
import '../services/firestore_notification_backend.dart';
import '../services/notification_sync_service.dart';
import '../services/device_sms_service.dart';
import '../services/network_status.dart';
import '../services/tts_service.dart';

enum AppRoute {
  welcome,
  login,
  register,
  forgotPassword,
  chooseRole,
  chooseLanguage,
  chooseTheme,
  chooseCategory,
  home,
  favorites,
  history,
  settings,
  profile,
  myChild,
  classes,
  notifications,
  teacherDashboard,
  teacherMyClasses,
  teacherMonitoring,
  teacherAlertHistory,
}

class AppState extends ChangeNotifier {
  AppState() {
    _bindTtsCallbacks();
    _init();
  }

  final AppRepository _repo = AppRepository(DatabaseHelper.instance);
  final TtsService tts = TtsService();
  final DeviceSmsService _deviceSms = DeviceSmsService();
  late final NotificationSyncService _notificationSync = NotificationSyncService(
    repository: _repo,
    cloudBackend: FirestoreNotificationBackend(),
  );

  bool _loading = true;
  UserModel? _user;
  AppRoute _route = AppRoute.welcome;
  TapTalkThemeToken _theme = TapTalkThemes.appDefault;
  AppLanguage _language = AppLanguage.english;
  int _languageRevision = 0;
  double _ttsSpeed = TtsSpeedOptions.defaultSpeed;
  String _selectedCategoryKey = 'feelings';
  bool _drawerOpen = false;
  bool _isSpeaking = false;
  String _speakingText = '';
  int _spokenWordStart = -1;
  int _spokenWordEnd = -1;
  Timer? _readAlongTimer;
  int _readAlongWordIndex = 0;
  int _ttsGeneration = 0;
  int? _currentSpeakGeneration;
  bool _speechPaused = false;
  String _pausedSpeechText = '';
  int _resumeWordIndex = 0;
  int _speechResumeCharOffset = 0;
  int _speechHighlightOffset = 0;
  List<String> _emergencyContacts = [];
  String _profileCode = '';

  List<CategoryModel> _categories = [];
  List<PhraseModel> _phrases = [];
  List<FavoriteModel> _favorites = [];
  List<HistoryModel> _history = [];
  List<LinkedChildModel> _linkedChildren = [];
  List<ParentNotification> _notifications = [];
  int? _selectedChildId;
  List<EnrolledClassModel> _enrolledClasses = [];
  List<({int id, String name, String code})> _teacherClasses = [];
  int _teacherStudentCount = 0;
  final Map<int, int> _teacherClassStudentCounts = {};
  final Set<String> _deletedClassCodes = {};
  int _teacherAlertsRevision = 0;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _monitoringSyncInFlight = false;

  bool get loading => _loading;
  UserModel? get user => _user;
  AppRoute get route => _route;
  TapTalkThemeToken get theme => _theme;
  AppLanguage get language => _language;
  int get languageRevision => _languageRevision;
  double get ttsSpeed => _ttsSpeed;
  String get selectedCategoryKey => _selectedCategoryKey;
  bool get drawerOpen => _drawerOpen;
  bool get isSpeaking => _isSpeaking;
  String get speakingText => _speakingText;
  int get spokenWordStart => _spokenWordStart;
  int get spokenWordEnd => _spokenWordEnd;

  /// Read-along highlight for a composer field only when it matches [spokenText].
  (int start, int end) composerHighlightRange(String composerText) {
    final active = _isSpeaking || _speechPaused;
    if (!active || _speakingText.trim() != composerText.trim()) {
      return (-1, -1);
    }
    return (_spokenWordStart, _spokenWordEnd);
  }

  List<String> get emergencyContacts => List.unmodifiable(_emergencyContacts);
  int? get _personalBoardUserId => _user?.id;

  /// For Me board: defaults + only this signed-in user's custom entries.
  List<CategoryModel> get categories {
    final ownerId = _personalBoardUserId;
    if (ownerId == null) return const [];
    return _categories.where((c) => c.userId == ownerId).toList();
  }

  List<PhraseModel> get phrases {
    final ownerId = _personalBoardUserId;
    if (ownerId == null) return const [];
    return _phrases.where((p) => p.userId == ownerId).toList();
  }

  List<FavoriteModel> get favorites {
    final ownerId = _personalBoardUserId;
    if (ownerId == null) return const [];
    return _favorites.where((f) => f.userId == ownerId).toList();
  }

  List<HistoryModel> get history {
    final ownerId = _personalBoardUserId;
    if (ownerId == null) return const [];
    return _history.where((h) => h.userId == ownerId).toList();
  }
  List<LinkedChildModel> get linkedChildren => _linkedChildren;
  List<ParentNotification> get notifications =>
      List.unmodifiable(_notifications);
  int get unreadNotificationCount =>
      _notifications.where((n) => !n.isRead).length;
  bool get isCloudNotificationsAvailable => _notificationSync.isCloudAvailable;
  List<EnrolledClassModel> get enrolledClasses => _enrolledClasses;
  List<({int id, String name, String code})> get teacherClasses =>
      _teacherClasses;
  int get teacherStudentCount => _teacherStudentCount;
  int get teacherAlertsRevision => _teacherAlertsRevision;
  int teacherClassStudentCount(int classId) =>
      _teacherClassStudentCounts[classId] ?? 0;
  int? get selectedChildId => _selectedChildId;

  LinkedChildModel? get selectedChild {
    if (_selectedChildId == null) return null;
    for (final c in _linkedChildren) {
      if (c.learnerId == _selectedChildId) return c;
    }
    return _linkedChildren.isNotEmpty ? _linkedChildren.first : null;
  }

  List<PhraseModel> get phrasesForCategory {
    final ownerId = _personalBoardUserId;
    if (ownerId == null) return const [];
    return _phrases
        .where(
          (p) =>
              p.userId == ownerId &&
              p.categoryKey == _selectedCategoryKey &&
              p.isActive,
        )
        .toList();
  }

  CategoryModel? get selectedCategory {
    for (final c in categories) {
      if (c.key == _selectedCategoryKey) return c;
    }
    return null;
  }

  bool _isPersonalBoardRoute(AppRoute route) {
    return route == AppRoute.home ||
        route == AppRoute.favorites ||
        route == AppRoute.history ||
        route == AppRoute.chooseCategory;
  }

  bool _isActiveSpeakGeneration() {
    final gen = _currentSpeakGeneration;
    return gen != null && gen == _ttsGeneration;
  }

  void _bindTtsCallbacks() {
    tts.onStart = () {
      if (!_isActiveSpeakGeneration()) return;
      _isSpeaking = true;
      notifyListeners();
    };
    tts.onProgress = (text, start, end, word) {
      if (!_isActiveSpeakGeneration()) return;
      _stopReadAlongFallback();
      _spokenWordStart = start + _speechHighlightOffset;
      _spokenWordEnd = end + _speechHighlightOffset;
      notifyListeners();
    };
    tts.onComplete = () {
      if (!_isActiveSpeakGeneration()) return;
      if (_speechPaused) return;
      _stopReadAlongFallback();
      _isSpeaking = false;
      _spokenWordStart = -1;
      _spokenWordEnd = -1;
      notifyListeners();
    };
    tts.onError = (_) {
      if (!_isActiveSpeakGeneration()) return;
      if (_speechPaused) return;
      _stopReadAlongFallback();
      _isSpeaking = false;
      _spokenWordStart = -1;
      _spokenWordEnd = -1;
      notifyListeners();
    };
  }

  List<(int, int)> _wordRanges(String text) {
    final matches = RegExp(r'\S+').allMatches(text);
    return matches.map((m) => (m.start, m.end)).toList();
  }

  int _wordIndexAtOffset(String text, int offset) {
    if (offset < 0) return 0;
    final ranges = _wordRanges(text);
    for (var i = 0; i < ranges.length; i++) {
      final (start, end) = ranges[i];
      if (offset < end) return i;
      if (offset == end && i + 1 < ranges.length) return i + 1;
    }
    return ranges.isEmpty ? 0 : ranges.length - 1;
  }

  void _startReadAlongFallback({int? fromWordIndex}) {
    _stopReadAlongFallback();
    final text = _speakingText.trim();
    if (text.isEmpty) return;
    final ranges = _wordRanges(_speakingText);
    if (ranges.isEmpty) return;
    _readAlongWordIndex = fromWordIndex ?? 0;
    final tick = Duration(
      milliseconds: (360 / _ttsSpeed).clamp(180, 700).round(),
    );
    _readAlongTimer = Timer.periodic(tick, (timer) {
      if (!_isSpeaking || ranges.isEmpty) {
        timer.cancel();
        return;
      }
      if (_readAlongWordIndex >= ranges.length) {
        _readAlongWordIndex = ranges.length - 1;
      }
      final (start, end) = ranges[_readAlongWordIndex];
      _spokenWordStart = start;
      _spokenWordEnd = end;
      notifyListeners();
      _readAlongWordIndex++;
      if (_readAlongWordIndex >= ranges.length) {
        timer.cancel();
      }
    });
  }

  void _stopReadAlongFallback() {
    _readAlongTimer?.cancel();
    _readAlongTimer = null;
  }

  void _resetSpeechTracking() {
    _stopReadAlongFallback();
    _isSpeaking = false;
    _speechPaused = false;
    _pausedSpeechText = '';
    _resumeWordIndex = 0;
    _speechResumeCharOffset = 0;
    _speechHighlightOffset = 0;
    _speakingText = '';
    _spokenWordStart = -1;
    _spokenWordEnd = -1;
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');

      if (userId != null) {
        _user = await _repo.findUserById(userId);
      }

      if (_user != null) {
        if (_user!.needsTheme) {
          _theme = TapTalkThemes.appDefault;
        } else {
          _theme = TapTalkThemes.byKey(_user!.themeKey);
        }
        await _loadLearnerData(cloudSyncInBackground: true);
        if (_user!.isLearner) {
          await _routeUserAfterOnboardingChecks();
        } else if (_user!.isParent) {
          await _ensureStarterData();
          await _loadLinkedChildren(syncCloudInBackground: true);
          await _routeUserAfterOnboardingChecks();
        } else if (_user!.isTeacher) {
          await _ensureStarterData();
          await refreshTeacherClasses(cloudSyncInBackground: true);
          await _routeUserAfterOnboardingChecks();
        } else {
          _route = AppRoute.login;
        }
      }
    } catch (e, st) {
      debugPrint('TapTalk init failed: $e\n$st');
      if (_user == null) _route = AppRoute.welcome;
    } finally {
      if (_user == null) {
        _route = AppRoute.welcome;
      }
      _loading = false;
      notifyListeners();
      unawaited(_initCloudServicesInBackground());
    }
  }

  /// Firebase (auth + notifications) and TTS — runs after the first screen is shown.
  Future<void> _initCloudServicesInBackground() async {
    try {
      unawaited(tts.init());
      // Auth (sign up / log in) needs Firebase even when no user is logged in yet.
      await FirebaseService.instance.initialize();
      await _activateMonitoringSync();
    } catch (e, st) {
      debugPrint('TapTalk cloud init failed: $e\n$st');
    }
  }

  /// Starts connectivity-based monitoring sync for the signed-in role.
  Future<void> _activateMonitoringSync() async {
    if (_user == null) return;

    final needsFullCloud = _user!.isParent ||
        _user!.isTeacher ||
        _user!.isOnlineAccount;
    final needsMonitoringSync =
        _user!.isLearner && CloudScope.syncMonitoring;

    if (needsFullCloud || needsMonitoringSync) {
      await _notificationSync.initialize();
    }

    _startMonitoringConnectivitySync();

    if (needsMonitoringSync) {
      await _syncPendingLearnerActivityToCloud();
      await _startLearnerEnrollmentSync();
    }

    if (!needsFullCloud) return;

    await _syncFirebaseSessionAfterRestore();
    if (_user!.isParent && CloudScope.notifications) {
      await _syncCloudDataAfterFirebaseReady();
    }
    if (_user!.isParent || _user!.isTeacher) {
      if (_user!.isTeacher) {
        await _syncTeacherClassesFromCloud();
        await _startTeacherMonitoringSync();
      }
      if (_user!.isParent) {
        await _startParentChildLinkSync();
      }
      unawaited(_prefetchMonitoredLearnerCaches());
    }
  }

  Future<void> _startLearnerEnrollmentSync() async {
    if (_user == null || !_user!.isLearner || !CloudScope.syncMonitoring) return;
    final uid = await _learnerFirebaseUidForSync();
    if (uid == null || uid.isEmpty) return;
    await _notificationSync.startLearnerEnrollmentSync(
      learnerFirebaseUid: uid,
      onChanged: () async {
        if (_user == null || !_user!.isLearner) return;
        try {
          // Never push before pull here — teacher may have deleted the class.
          await _syncEnrolledClassesFromCloud();
          _enrolledClasses = await _repo.getEnrolledClasses(_user!.id);
          notifyListeners();
        } catch (e, st) {
          debugPrint('Learner enrollment live sync failed: $e\n$st');
        }
      },
    );
  }

  Future<void> _startParentChildLinkSync() async {
    if (_user == null || !_user!.isParent || !CloudScope.syncMonitoring) return;
    final parentFirebaseUid = await _resolveParentFirebaseUid();
    if (parentFirebaseUid == null) return;
    await _notificationSync.startParentChildLinkSync(
      parentFirebaseUid: parentFirebaseUid,
      onChanged: () async {
        if (_user == null || !_user!.isParent) return;
        try {
          await _syncLinkedChildrenFromCloud();
          _linkedChildren = await _repo.getLinkedChildren(_user!.id);
          notifyListeners();
        } catch (e, st) {
          debugPrint('Parent child link live sync failed: $e\n$st');
        }
      },
    );
  }

  Future<void> _startTeacherMonitoringSync() async {
    if (_user == null || !_user!.isTeacher || !CloudScope.syncMonitoring) return;
    final teacherFirebaseUid = await _resolveAccountFirebaseUid();
    if (teacherFirebaseUid == null) return;
    await _notificationSync.startTeacherMonitoringSync(
      teacherFirebaseUid: teacherFirebaseUid,
      onEnrollmentsChanged: (enrollments) async {
        if (_user == null || !_user!.isTeacher) return;
        try {
          await _repo.mergeRemoteEnrollmentsForTeacher(
            teacherUserId: _user!.id,
            enrollments: enrollments,
          );
          await _refreshTeacherClassCounts();
          notifyListeners();
        } catch (e, st) {
          debugPrint('Teacher enrollment live sync failed: $e\n$st');
        }
      },
      onClassesChanged: (remoteClasses) async {
        if (_user == null || !_user!.isTeacher) return;
        try {
          await _repo.mergeRemoteTeacherClasses(
            teacherUserId: _user!.id,
            remoteClasses: remoteClasses,
            skipClassCodes: _deletedClassCodes,
          );
          final remoteClassCodes = remoteClasses
              .map((c) => AppRepository.normalizeClassCode(c.classCode))
              .where(AppRepository.isValidClassCodeFormat)
              .toSet();
          await _repo.pruneStaleTeacherClasses(
            teacherUserId: _user!.id,
            remoteClassCodes: remoteClassCodes,
            skipClassCodes: _deletedClassCodes,
          );
          await _loadTeacherClasses();
          await _refreshTeacherClassCounts();
          notifyListeners();
        } catch (e, st) {
          debugPrint('Teacher class live sync failed: $e\n$st');
        }
      },
    );
  }

  Future<void> _syncCloudDataAfterFirebaseReady() async {
    if (_user == null || !CloudScope.notifications) return;
    try {
      if (_user!.isParent) {
        await _syncLinkedChildrenFromCloud();
        _linkedChildren = await _repo.getLinkedChildren(_user!.id);
        if (_linkedChildren.isEmpty) {
          _selectedChildId = null;
        } else if (_selectedChildId == null ||
            !_linkedChildren.any((c) => c.learnerId == _selectedChildId)) {
          _selectedChildId = _linkedChildren.first.learnerId;
        }
        await _loadNotifications();
        await _syncLinkedChildrenToCloud();
        await _startParentNotificationSync();
        await _startParentChildLinkSync();
      }
      notifyListeners();
    } catch (e, st) {
      debugPrint('Post-firebase notification sync failed: $e\n$st');
    }
  }

  String _categoryOnboardingKey(int userId) => 'category_onboarding_$userId';

  String _languageOnboardingKey(int userId) => 'language_onboarding_$userId';

  String _languagePrefKey(int userId) => 'lang_$userId';

  String _ttsSpeedPrefKey(int userId) => 'tts_speed_$userId';

  Future<bool> _isCategoryOnboardingDone(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _categoryOnboardingKey(userId);
    if (!prefs.containsKey(key)) {
      // Existing users before category onboarding — skip the extra step.
      await prefs.setBool(key, true);
      return true;
    }
    return prefs.getBool(key) ?? false;
  }

  Future<void> _setCategoryOnboardingDone(int userId, bool done) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_categoryOnboardingKey(userId), done);
  }

  Future<bool> _isLanguageOnboardingDone(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_languageOnboardingKey(userId)) ?? false;
  }

  Future<void> _setLanguageOnboardingDone(int userId, bool done) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_languageOnboardingKey(userId), done);
  }

  Future<void> _routeUserAfterOnboardingChecks() async {
    if (_user == null) return;
    final languageDone = await _isLanguageOnboardingDone(_user!.id);
    if (!languageDone) {
      _route = AppRoute.chooseLanguage;
      return;
    }
    if (_user!.isLearner) {
      if (_user!.needsTheme) {
        _route = AppRoute.chooseTheme;
        return;
      }
      await _ensureStarterData();
      final categoryDone = await _isCategoryOnboardingDone(_user!.id);
      _route = categoryDone ? AppRoute.home : AppRoute.chooseCategory;
    } else if (_user!.isParent) {
      _route = AppRoute.home;
    } else if (_user!.isTeacher) {
      _route = AppRoute.teacherDashboard;
    }
  }

  /// Clears in-memory words/phrases/categories so a new login never briefly
  /// shows another account's customized content.
  void _resetLearnerSessionData() {
    _categories = [];
    _phrases = [];
    _favorites = [];
    _history = [];
    _selectedCategoryKey = 'feelings';
    _profileCode = '';
    _enrolledClasses = [];
    _emergencyContacts = [];
  }

  void _resetAccountSession() {
    _resetLearnerSessionData();
    _linkedChildren = [];
    _notifications = [];
    _selectedChildId = null;
    _teacherClasses = [];
    _teacherStudentCount = 0;
    _teacherClassStudentCounts.clear();
    _deletedClassCodes.clear();
  }

  Future<void> _loadLearnerData({bool cloudSyncInBackground = false}) async {
    if (_user == null) return;
    final userId = _user!.id;
    if (_user!.isLearner || _user!.isParent || _user!.isTeacher) {
      await _repo.dedupeBuiltinPhrases(userId);
    }
    final settings = await _repo.getUserSettings(_user!.id);
    _ttsSpeed = TtsSpeedOptions.snap(
      (settings['tts_speed'] as num?)?.toDouble() ?? TtsSpeedOptions.defaultSpeed,
    );
    _applyLanguageFromSettings(settings);
    await _restoreLanguagePref();
    await _syncLanguagePref();
    await _syncTtsSpeedPref();
    final contacts = settings['emergency_contacts'];
    if (contacts is List) {
      _emergencyContacts =
          AppRepository.normalizeEmergencyContacts(contacts.whereType<String>().toList());
    } else {
      _emergencyContacts = [];
    }

    if (_user!.isLearner) {
      _profileCode = await _repo.ensureLearnerProfileCode(_user!.id);
      _enrolledClasses = await _repo.getEnrolledClasses(_user!.id);
      if (cloudSyncInBackground) {
        unawaited(_syncLearnerCloudData());
      } else {
        await _syncLearnerCloudData();
      }
    } else {
      _profileCode = '';
      _enrolledClasses = [];
    }

    _categories = (await _repo.getCategories(userId))
        .where((c) => c.userId == userId)
        .toList();
    _phrases = (await _repo.getPhrases(userId))
        .where((p) => p.userId == userId)
        .toList();
    _favorites = (await _repo.getFavorites(userId))
        .where((f) => f.userId == userId)
        .toList();
    _history = (await _repo.getHistory(userId))
        .where((h) => h.userId == userId)
        .toList();

    if (_categories.isNotEmpty &&
        !_categories.any((c) => c.key == _selectedCategoryKey)) {
      _selectedCategoryKey = _categories.first.key;
    }
  }

  Future<void> _syncLearnerCloudData() async {
    if (_user == null || !_user!.isLearner) return;
    try {
      if (CloudScope.syncMonitoring) {
        await _syncLearnerCategoriesToCloud();
        await _syncLearnerCustomPhrasesToCloud();
        await _syncPendingLearnerActivityToCloud();
        await _resyncLearnerEnrollmentsToCloud();
        final learnerFirebaseUid = await _learnerFirebaseUidForSync();
        if (learnerFirebaseUid != null && learnerFirebaseUid.isNotEmpty) {
          await _notificationSync.syncLearnerEmergencyContacts(
            learnerUserId: _user!.id,
            learnerName: _user!.fullName,
            learnerFirebaseUid: learnerFirebaseUid,
            contacts: _emergencyContacts,
            profileCode: _profileCode,
          );
        }
      }
      await _syncUserProfileToCloud();
      await _loadEnrolledClasses();
      notifyListeners();
    } catch (e, st) {
      debugPrint('Learner cloud sync failed: $e\n$st');
    }
  }

  Future<void> _syncUserProfileToCloud() async {
    if (_user == null) return;
    await FirebaseService.instance.initialize();
    await _notificationSync.initialize();
    if (!_notificationSync.isCloudAvailable) return;
    final firebaseUid =
        _user!.firebaseUid ?? FirebaseService.instance.currentUid;
    if (firebaseUid == null || firebaseUid.isEmpty) return;

    String? profileCode;
    if (_user!.isLearner) {
      profileCode = _profileCode.isNotEmpty
          ? _profileCode
          : await _repo.ensureLearnerProfileCode(_user!.id);
    }

    await _notificationSync.syncUserProfile(
      RemoteUserProfile(
        firebaseUid: firebaseUid,
        email: _user!.email,
        fullName: _user!.fullName,
        role: _user!.role,
        themeKey: _user!.themeKey,
        profileCode: profileCode,
      ),
    );

    if (_user!.isLearner && CloudScope.syncMonitoring) {
      await _notificationSync.syncLearnerEmergencyContacts(
        learnerUserId: _user!.id,
        learnerName: _user!.fullName,
        learnerFirebaseUid: firebaseUid,
        contacts: _emergencyContacts,
        profileCode: profileCode,
      );
    }
  }

  Future<void> _refreshPersonalBoard() async {
    if (_user == null) return;
    final ownerId = _user!.id;
    _categories = (await _repo.getCategories(ownerId))
        .where((c) => c.userId == ownerId)
        .toList();
    _phrases = (await _repo.getPhrases(ownerId))
        .where((p) => p.userId == ownerId)
        .toList();
    _favorites = (await _repo.getFavorites(ownerId))
        .where((f) => f.userId == ownerId)
        .toList();
    _history = (await _repo.getHistory(ownerId))
        .where((h) => h.userId == ownerId)
        .toList();
    if (_categories.isNotEmpty &&
        !_categories.any((c) => c.key == _selectedCategoryKey)) {
      _selectedCategoryKey = _categories.first.key;
    }
  }

  Future<void> _refreshLearnerCollections() => _refreshPersonalBoard();

  Future<void> _ensureStarterData() async {
    if (_user == null ||
        (!_user!.isParent && !_user!.isLearner && !_user!.isTeacher)) {
      return;
    }
    await _repo.dedupeBuiltinPhrases(_user!.id);
    if (await _repo.hasStarterPersonalData(_user!.id)) {
      if (_categories.isEmpty) {
        await _refreshLearnerCollections();
      }
      return;
    }
    await _repo.seedLearnerData(_user!.id);
    await _refreshLearnerCollections();
  }

  Future<void> setRoute(AppRoute route) async {
    if (_drawerOpen) {
      _drawerOpen = false;
      notifyListeners();
      await Future<void>.delayed(AppSpacing.drawerAnimation);
    }
    if (_route == route) return;
    _route = route;
    if (_isPersonalBoardRoute(route) && _user != null) {
      await _refreshPersonalBoard();
    }
    notifyListeners();
  }

  void toggleDrawer([bool? open]) {
    _drawerOpen = open ?? !_drawerOpen;
    notifyListeners();
  }

  void selectCategory(String key) {
    _selectedCategoryKey = key;
    notifyListeners();
  }

  void _applyLanguageFromSettings(Map<String, dynamic> settings) {
    final raw = settings['language'];
    if (raw is! String || raw.trim().isEmpty) return;
    _applyLanguageCode(raw);
  }

  void _applyLanguageCode(String raw) {
    final norm = raw.trim().toLowerCase();
    if (norm.startsWith('fil') || norm == 'tagalog') {
      _language = AppLanguage.filipino;
    } else if (norm.startsWith('en')) {
      _language = AppLanguage.english;
    }
  }

  Future<void> _restoreLanguagePref() async {
    if (_user == null) return;
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_languagePrefKey(_user!.id));
    if (code == null || code.trim().isEmpty) return;
    _applyLanguageCode(code);
  }

  Future<void> _syncLanguagePref() async {
    if (_user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _languagePrefKey(_user!.id),
      AppStrings.langCode(_language),
    );
  }

  Future<void> _syncTtsSpeedPref() async {
    if (_user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_ttsSpeedPrefKey(_user!.id), _ttsSpeed);
  }

  Future<void> setLanguage(AppLanguage lang) async {
    if (_language == lang) return;
    _language = lang;
    _languageRevision++;
    notifyListeners();
    try {
      await _syncLanguagePref();
      if (_user != null) {
        await _repo.updateUserSettings(
          _user!.id,
          language: lang == AppLanguage.filipino ? 'Filipino' : 'English',
        );
      }
    } catch (e, st) {
      debugPrint('setLanguage persist failed: $e\n$st');
    }
  }

  Future<void> setTtsSpeed(double speed) async {
    _ttsSpeed = TtsSpeedOptions.snap(speed);
    await _syncTtsSpeedPref();
    if (_user != null) {
      await _repo.updateUserSettings(_user!.id, ttsSpeed: _ttsSpeed);
    }
    notifyListeners();
  }

  Future<void> setTheme(String themeKey) async {
    _theme = TapTalkThemes.byKey(themeKey);
    if (_user != null) {
      await _repo.updateUserTheme(_user!.id, themeKey);
      _user = _user!.copyWith(themeKey: themeKey);
    }
    notifyListeners();
  }

  void previewTheme(String themeKey) {
    final next = TapTalkThemes.byKey(themeKey);
    if (_theme.key == next.key) return;
    _theme = next;
    notifyListeners();
  }

  /// Stored phrase text only — UI language does not translate user phrases.
  String localizedPhrase(String text, String categoryKey) => text;

  String localizedPhraseText(PhraseModel phrase) => phrase.text;

  /// Stored content only — class names, lessons, etc. are not auto-translated.
  String localizedContent(String text) => text;

  String localizedCategoryName(CategoryModel category) =>
      ContentLocalization.category(category.key, category.name, _language);

  String localizedCategoryKey(String categoryKey, {String? storedName}) =>
      ContentLocalization.category(
        AppRepository.normalizeCategoryKey(categoryKey),
        storedName ?? categoryKey,
        _language,
      );

  String localizedThemeName(String themeKey, String storedName) =>
      ContentLocalization.themeName(themeKey, storedName, _language);

  Future<String?> login(String email, String password) async {
    try {
      return await _loginImpl(email, password);
    } catch (e, st) {
      debugPrint('Login error: $e\n$st');
      return AppStrings.loginFailedTryAgain(_language);
    }
  }

  Future<String?> _loginImpl(String email, String password) async {
    final normalizedEmail = AuthValidation.normalizeEmail(email);
    if (!AuthValidation.isValidEmail(normalizedEmail)) {
      return AppStrings.invalidEmail(_language);
    }
    if (password.isEmpty) {
      return AppStrings.fillAllFields(_language);
    }

    await FirebaseService.instance.initialize();
    final offline = await NetworkStatus.isOffline();

    var user = await _repo.findUserByEmail(normalizedEmail);
    if (user == null) {
      if (offline || !FirebaseService.instance.isAvailable) {
        return AppStrings.loginNeedsInternet(_language);
      }
      // Account may exist only in Firebase (registered on another device).
      if (FirebaseService.instance.isAvailable) {
        final uid = await FirebaseService.instance.signIn(
          email: normalizedEmail,
          password: password,
        );
        if (uid != null) {
          final cloudProfile =
              await _notificationSync.resolveUserProfileForLogin(
            firebaseUid: uid,
            email: normalizedEmail,
          );
          user = await _repo.provisionLocalUserFromCloud(
            email: normalizedEmail,
            password: password,
            firebaseUid: uid,
            profile: cloudProfile,
          );
        }
      }
      if (user == null) {
        return AppStrings.emailNotRegistered(_language);
      }
    }

    if (FirebaseService.instance.isAvailable) {
      final uid = await FirebaseService.instance.signIn(
        email: normalizedEmail,
        password: password,
      );
      if (uid != null) {
        if (user.firebaseUid != uid) {
          await _repo.linkFirebaseUid(user.id, uid);
          user = user.copyWith(firebaseUid: uid);
        }
        final hashed = AppRepository.hashPassword(password);
        if (user.passwordHash != hashed) {
          await _repo.updatePasswordHash(user.id, password);
          user = user.copyWith(passwordHash: hashed);
        }
      } else {
        final ok = await _repo.verifyLogin(normalizedEmail, password);
        if (!ok) return AppStrings.wrongPassword(_language);
        unawaited(
          _linkFirebaseAccountIfAvailable(
            user: user,
            email: normalizedEmail,
            password: password,
          ),
        );
      }
    } else {
      final ok = await _repo.verifyLogin(normalizedEmail, password);
      if (!ok) return AppStrings.wrongPassword(_language);
      unawaited(
        _linkFirebaseAccountIfAvailable(
          user: user,
          email: normalizedEmail,
          password: password,
        ),
      );
    }

    _user = user;
    if (_user == null) return AppStrings.loginFailed(_language);

    _resetAccountSession();

    unawaited(_syncUserProfileToCloud());

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', _user!.id);
    if (_user!.isLearner || _user!.isParent || _user!.isTeacher) {
      if (_user!.needsTheme) {
        _theme = TapTalkThemes.appDefault;
      } else {
        _theme = TapTalkThemes.byKey(_user!.themeKey ?? 'mint_green');
      }
      await _routeUserAfterOnboardingChecks();
    } else {
      _route = AppRoute.login;
      return AppStrings.parentTeacherComingSoon(_language);
    }

    notifyListeners();

    try {
      if (_user!.isLearner) {
        await _loadLearnerData(cloudSyncInBackground: false);
        await _ensureStarterData();
      } else if (_user!.isParent) {
        await _loadLearnerData(cloudSyncInBackground: true);
        await _ensureStarterData();
        await _loadLinkedChildren(syncCloudInBackground: true);
        await _notificationSync.initialize();
        await _syncFirebaseSessionAfterRestore();
        await _syncCloudDataAfterFirebaseReady();
      } else if (_user!.isTeacher) {
        await _loadLearnerData(cloudSyncInBackground: true);
        await _ensureStarterData();
        await refreshTeacherClasses(cloudSyncInBackground: true);
        await _notificationSync.initialize();
        await _syncFirebaseSessionAfterRestore();
      }
      unawaited(_activateMonitoringSync());
      notifyListeners();
    } catch (e, st) {
      debugPrint('Post-login data load failed (session is saved): $e\n$st');
    }

    return null;
  }

  /// True when this device already has an account with the email.
  /// Firebase Auth is checked again when the user taps Create account.
  Future<bool> isEmailAlreadyInUse(String email) async {
    final normalizedEmail = AuthValidation.normalizeEmail(email);
    if (!AuthValidation.isValidEmail(normalizedEmail)) return false;

    final existing = await _repo.findUserByEmail(normalizedEmail);
    return existing != null;
  }

  Future<String?> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      return await _registerImpl(
        fullName: fullName,
        email: email,
        password: password,
        role: role,
      );
    } catch (e, st) {
      debugPrint('Register error: $e\n$st');
      return AppStrings.signUpFailedTryAgain(_language);
    }
  }

  Future<String?> _registerImpl({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    final normalizedEmail = AuthValidation.normalizeEmail(email);
    if (!AuthValidation.isValidFullName(fullName)) {
      return AppStrings.invalidFullName(_language);
    }
    if (!AuthValidation.isValidEmail(normalizedEmail)) {
      return AppStrings.invalidEmail(_language);
    }
    if (!AuthValidation.isStrongPassword(password)) {
      return AppStrings.passwordTooShort(_language);
    }

    await FirebaseService.instance.initialize();
    if (await NetworkStatus.isOffline()) {
      return AppStrings.signUpRequiresInternet(_language);
    }

    final existing = await _repo.findUserByEmail(normalizedEmail);
    if (existing != null) return AppStrings.emailInUse(_language);

    String? firebaseUid;
    if (FirebaseService.instance.isAvailable) {
      firebaseUid = await FirebaseService.instance.createAccount(
        email: normalizedEmail,
        password: password,
      );
      if (firebaseUid == null) {
        if (FirebaseService.instance.lastAuthErrorCode ==
            'email-already-in-use') {
          return AppStrings.emailInUse(_language);
        }
        if (FirebaseService.instance.lastAuthErrorCode == 'weak-password') {
          return AppStrings.passwordTooShort(_language);
        }
        return AppStrings.signUpOnlineAccountFailed(_language);
      }
    } else {
      return AppStrings.signUpRequiresInternet(_language);
    }

    try {
      _user = await _repo.registerUser(
        fullName: fullName,
        email: normalizedEmail,
        password: password,
        role: role,
        firebaseUid: firebaseUid,
      );
    } catch (e) {
      debugPrint('registerUser database error: $e');
      final msg = e.toString().toLowerCase();
      if (msg.contains('unique') || msg.contains('constraint')) {
        return AppStrings.emailInUse(_language);
      }
      rethrow;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', _user!.id);
    _resetAccountSession();
    if (role == 'learner') {
      _theme = TapTalkThemes.appDefault;
      await _setLanguageOnboardingDone(_user!.id, false);
      await _setCategoryOnboardingDone(_user!.id, false);
      _route = AppRoute.chooseLanguage;
    } else if (role == 'parent') {
      _theme = TapTalkThemes.byKey(_user!.themeKey ?? 'mint_green');
      await _setLanguageOnboardingDone(_user!.id, false);
      _route = AppRoute.chooseLanguage;
    } else if (role == 'teacher') {
      _theme = TapTalkThemes.byKey(_user!.themeKey ?? 'mint_green');
      await _setLanguageOnboardingDone(_user!.id, false);
      _route = AppRoute.chooseLanguage;
    } else {
      _route = AppRoute.login;
    }

    notifyListeners();

    try {
      await _syncUserProfileToCloud();
      if (role == 'learner') {
        await _loadLearnerData(cloudSyncInBackground: false);
        await _ensureStarterData();
      } else if (role == 'parent') {
        await _loadLearnerData(cloudSyncInBackground: true);
        await _ensureStarterData();
        await _loadLinkedChildren(syncCloudInBackground: true);
      } else if (role == 'teacher') {
        await _loadLearnerData(cloudSyncInBackground: true);
        await _ensureStarterData();
        await refreshTeacherClasses(cloudSyncInBackground: true);
      }
      unawaited(_activateMonitoringSync());
      notifyListeners();
    } catch (e, st) {
      debugPrint('Post-register data load failed (account is saved): $e\n$st');
    }

    return null;
  }

  Future<PasswordResetStartOutcome> beginPasswordReset(String email) async {
    final normalizedEmail = AuthValidation.normalizeEmail(email);
    if (!AuthValidation.isValidEmail(normalizedEmail)) {
      return PasswordResetStartOutcome.error(
        AppStrings.invalidEmail(_language),
      );
    }
    final user = await _repo.findUserByEmail(normalizedEmail);
    if (user == null) {
      return PasswordResetStartOutcome.error(
        AppStrings.emailNotRegistered(_language),
      );
    }

    if (await NetworkStatus.isOffline()) {
      return PasswordResetStartOutcome.error(
        AppStrings.noInternetConnection(_language),
      );
    }

    if (!FirebaseService.instance.isAvailable) {
      return PasswordResetStartOutcome.error(
        AppStrings.localPasswordResetUnavailable(_language),
      );
    }

    if (user.firebaseUid == null || user.firebaseUid!.trim().isEmpty) {
      final uid =
          await FirebaseService.instance.provisionAuthAccountForPasswordReset(
        email: normalizedEmail,
      );
      if (uid != null) {
        await _repo.linkFirebaseUid(user.id, uid);
      }
    }

    final result = await FirebaseService.instance.sendPasswordResetEmail(
      email: normalizedEmail,
    );
    if (result.success) {
      return PasswordResetStartOutcome.emailSent();
    }

    return PasswordResetStartOutcome.error(
      _passwordResetErrorMessage(result.errorCode),
    );
  }

  String _passwordResetErrorMessage(String? code) {
    switch (code) {
      case 'too-many-requests':
        return AppStrings.passwordResetTooManyRequests(_language);
      case 'invalid-email':
        return AppStrings.invalidEmail(_language);
      case 'unavailable':
      case 'timeout':
        return AppStrings.localPasswordResetUnavailable(_language);
      default:
        return AppStrings.passwordResetEmailFailed(_language);
    }
  }

  Future<String?> completeLocalPasswordReset(
    String email,
    String newPassword,
  ) async {
    if (!AuthValidation.isStrongPassword(newPassword)) {
      return AppStrings.passwordTooShort(_language);
    }
    final normalizedEmail = email.trim().toLowerCase();
    final ok = await _repo.resetPasswordByEmail(normalizedEmail, newPassword);
    if (!ok) return AppStrings.emailNotRegistered(_language);
    return null;
  }

  Future<void> logout() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    await _notificationSync.stopParentSync();
    await _notificationSync.stopMonitoringSync();
    await FirebaseService.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    _language = AppLanguage.english;
    _languageRevision = 0;
    _ttsSpeed = TtsSpeedOptions.defaultSpeed;
    _user = null;
    _resetAccountSession();
    _theme = TapTalkThemes.appDefault;
    _resetSpeechTracking();
    _route = AppRoute.welcome;
    _drawerOpen = false;
    notifyListeners();
  }

  Future<void> completeLanguageSelection(AppLanguage lang) async {
    await setLanguage(lang);
    if (_user != null) {
      await _setLanguageOnboardingDone(_user!.id, true);
    }
    if (_user?.isLearner ?? false) {
      _route = AppRoute.chooseTheme;
    } else if (_user?.isParent ?? false) {
      _route = AppRoute.home;
    } else if (_user?.isTeacher ?? false) {
      _route = AppRoute.teacherDashboard;
    }
    notifyListeners();
  }

  Future<void> completeThemeSelection(String themeKey) async {
    await setTheme(themeKey);
    _route = AppRoute.chooseCategory;
    notifyListeners();
  }

  Future<void> completeCategorySelection(String categoryKey) async {
    selectCategory(categoryKey);
    if (_user != null) {
      await _setCategoryOnboardingDone(_user!.id, true);
      await _refreshPersonalBoard();
    }
    _route = AppRoute.home;
    notifyListeners();
  }

  Future<String?> addCategory(String name) async {
    if (_user == null) return AppStrings.notSignedIn(_language);
    try {
      final cat = await _repo.addCategory(_user!.id, name);
      if (_user!.isLearner) {
        unawaited(_syncLearnerCategoriesToCloud());
      }
      _selectedCategoryKey = cat.key;
      await _refreshPersonalBoard();
      notifyListeners();
      return null;
    } catch (e) {
      return AppStrings.unableAddCategory(_language);
    }
  }

  Future<String?> addPhrase(String text, {String? imagePath}) async {
    if (_user == null || text.trim().isEmpty) return null;
    final savedImagePath = await persistPhraseImageIfNeeded(imagePath);
    final stored = text.trim();
    await _repo.addPhrase(
      userId: _user!.id,
      text: stored,
      categoryKey: _selectedCategoryKey,
      imagePath: savedImagePath,
    );
    if (_user!.isLearner) {
      unawaited(_syncLearnerCustomPhrasesToCloud());
    }
    await _refreshPersonalBoard();
    notifyListeners();
    return null;
  }

  Future<void> deletePhrase(PhraseModel phrase) async {
    if (_user == null || phrase.userId != _user!.id) return;
    if (!phrase.isBuiltin) {
      await _repo.deletePhrase(_user!.id, phrase.id);
      if (_user!.isLearner) {
        unawaited(_syncLearnerCustomPhrasesToCloud());
      }
    }
    await _refreshPersonalBoard();
    notifyListeners();
  }

  Future<bool> updatePhrase(
    PhraseModel phrase, {
    required String text,
    String? imagePath,
    required bool clearImage,
  }) async {
    if (_user == null || phrase.userId != _user!.id) return false;
    if (phrase.isBuiltin) return false;

    final savedImage = clearImage
        ? null
        : await persistPhraseImageIfNeeded(imagePath ?? phrase.imagePath);

    final ok = await _repo.updatePhrase(
      userId: _user!.id,
      phraseId: phrase.id,
      text: text,
      imagePath: savedImage,
    );
    await _refreshPersonalBoard();
    notifyListeners();
    return ok;
  }

  bool isFavorite(PhraseModel phrase) {
    final key = '${phrase.text.trim().toLowerCase()}__${phrase.categoryKey}';
    return _favorites.any((f) => f.dedupeKey == key);
  }

  int? favoriteIdFor(PhraseModel phrase) {
    final key = '${phrase.text.trim().toLowerCase()}__${phrase.categoryKey}';
    for (final f in _favorites) {
      if (f.dedupeKey == key) return f.id;
    }
    return null;
  }

  Future<void> toggleFavorite(PhraseModel phrase) async {
    if (_user == null || phrase.userId != _user!.id) return;
    final favId = favoriteIdFor(phrase);
    if (favId != null) {
      await _repo.removeFavorite(favId);
    } else {
      await _repo.addFavorite(
        userId: _user!.id,
        phraseText: phrase.text,
        categoryKey: phrase.categoryKey,
        phraseId: phrase.isBuiltin ? null : phrase.id,
        imagePath: phrase.imagePath,
      );
    }
    _favorites = await _repo.getFavorites(_user!.id);
    notifyListeners();
  }

  Future<void> recordHistory(
    String text, {
    String? categoryKey,
    String? className,
    String? lessonTitle,
  }) async {
    if (_user == null || text.trim().isEmpty) return;
    final stored = text.trim();
    final baseCategoryKey = categoryKey ?? _selectedCategoryKey;
    final storedCategoryKey = AppRepository.resolveHistoryCategoryKey(
      categoryKey: baseCategoryKey,
      className: className,
      lessonTitle: lessonTitle,
    );
    final cloudCategoryKey = AppRepository.isLessonCategoryKey(storedCategoryKey)
        ? storedCategoryKey
        : AppRepository.normalizeCategoryKey(baseCategoryKey);
    final now = DateTime.now();
    final historyId = await _repo.addHistory(
      userId: _user!.id,
      text: stored,
      categoryKey: baseCategoryKey,
      className: className,
      lessonTitle: lessonTitle,
      createdAt: now,
    );
    _history = await _repo.getHistory(_user!.id);
    notifyListeners();
    if (historyId != null) {
      unawaited(
        _pushHistoryItemToCloud(
          historyId: historyId,
          phraseText: stored,
          categoryKey: cloudCategoryKey,
          createdAt: now,
          className: className,
          lessonTitle: lessonTitle,
        ),
      );
    }
  }

  Future<String?> _learnerFirebaseUidForSync() async {
    if (_user == null || !_user!.isLearner) return null;
    final uid = _user!.firebaseUid ?? FirebaseService.instance.currentUid;
    if (uid != null && uid.isNotEmpty) return uid;
    if (!FirebaseService.instance.isAvailable) return null;
    final restored = await FirebaseService.instance.waitForAuthUid();
    if (restored != null && restored.isNotEmpty) {
      if (_user!.firebaseUid == null || _user!.firebaseUid!.isEmpty) {
        await _repo.linkFirebaseUid(_user!.id, restored);
        _user = _user!.copyWith(firebaseUid: restored);
      }
      return restored;
    }
    return null;
  }

  Future<void> _pushHistoryItemToCloud({
    required int historyId,
    required String phraseText,
    required String categoryKey,
    required DateTime createdAt,
    String? className,
    String? lessonTitle,
  }) async {
    if (!CloudScope.syncMonitoring) return;
    if (_user == null || !_user!.isLearner) return;
    if (await NetworkStatus.isOffline() || NetworkStatus.isCloudBlocked) return;
    await FirebaseService.instance.initialize();
    await _notificationSync.initialize();
    if (!_notificationSync.isCloudAvailable) return;
    final uid = await _learnerFirebaseUidForSync();
    if (uid == null || uid.isEmpty) return;
    final syncKey = AppRepository.remoteActivitySyncKey(
      createdAt: createdAt,
      phraseText: phraseText,
      categoryKey: categoryKey,
    );
    final pushed = await _notificationSync.pushLearnerActivity(
      LearnerActivityCloudEvent(
        learnerFirebaseUid: uid,
        phraseText: phraseText,
        categoryKey: categoryKey,
        createdAt: createdAt,
        className: className,
        lessonTitle: lessonTitle,
      ),
    );
    if (pushed) {
      await _repo.markHistoryCloudSynced(
        historyId: historyId,
        syncKey: syncKey,
      );
    }
  }

  /// Uploads learner phrase history captured offline once the device is online.
  Future<void> _syncPendingLearnerActivityToCloud() async {
    if (!CloudScope.syncMonitoring) return;
    if (_user == null || !_user!.isLearner) return;
    if (_monitoringSyncInFlight) return;
    if (await NetworkStatus.isOffline() || NetworkStatus.isCloudBlocked) return;
    await FirebaseService.instance.initialize();
    await _notificationSync.initialize();
    if (!_notificationSync.isCloudAvailable) return;
    final uid = await _learnerFirebaseUidForSync();
    if (uid == null || uid.isEmpty) return;

    _monitoringSyncInFlight = true;
    try {
      final pending = await _repo.getUnsyncedHistory(_user!.id);
      for (final item in pending) {
        if (await NetworkStatus.isOffline()) break;
        final storedCategoryKey = AppRepository.resolveHistoryCategoryKey(
          categoryKey: item.categoryKey,
          className: item.className,
          lessonTitle: item.lessonTitle,
        );
        final categoryKey = AppRepository.isLessonCategoryKey(storedCategoryKey)
            ? storedCategoryKey
            : AppRepository.normalizeCategoryKey(item.categoryKey);
        final syncKey = AppRepository.syncKeyForHistoryItem(item);
        final pushed = await _notificationSync.pushLearnerActivity(
          LearnerActivityCloudEvent(
            learnerFirebaseUid: uid,
            phraseText: item.text.trim(),
            categoryKey: categoryKey,
            createdAt: item.createdAt,
            className: item.className,
            lessonTitle: item.lessonTitle,
          ),
        );
        if (pushed) {
          await _repo.markHistoryCloudSynced(
            historyId: item.id,
            syncKey: syncKey,
          );
        }
      }
    } catch (e, st) {
      debugPrint('Sync pending learner activity failed: $e\n$st');
    } finally {
      _monitoringSyncInFlight = false;
    }
  }

  void _startMonitoringConnectivitySync() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      if (results.isEmpty ||
          results.every((r) => r == ConnectivityResult.none)) {
        return;
      }
      unawaited(_onConnectivityRestored());
    });
  }

  Future<void> _onConnectivityRestored() async {
    if (_user == null) return;
    if (await NetworkStatus.isOffline() || NetworkStatus.isCloudBlocked) return;

    await FirebaseService.instance.initialize();
    await _notificationSync.initialize();

    if (_user!.isLearner && CloudScope.syncMonitoring) {
      await _syncLearnerCloudData();
      await refreshEnrolledClasses(cloudSyncInBackground: false);
      return;
    }
    if (_user!.isParent || _user!.isTeacher) {
      await _syncFirebaseSessionAfterRestore();
      if (_user!.isParent) {
        await refreshLinkedChildren(cloudSyncInBackground: false);
      }
      if (_user!.isTeacher) {
        await refreshTeacherClasses(cloudSyncInBackground: false);
      }
      await _prefetchMonitoredLearnerCaches();
    }
  }

  Future<void> _prefetchMonitoredLearnerCaches() async {
    if (_user == null) return;
    if (await NetworkStatus.isOffline() || !_notificationSync.isCloudAvailable) {
      return;
    }
    if (_user!.isParent) {
      if (_linkedChildren.isEmpty) {
        await _loadLinkedChildren(syncCloudInBackground: false);
      }
      for (final child in _linkedChildren) {
        await refreshChildMonitoringData(child.learnerId);
      }
      return;
    }
    if (_user!.isTeacher) {
      await _syncTeacherClassesFromCloud();
      final students = await _repo.getTeacherClassStudents(_user!.id);
      final seen = <int>{};
      for (final student in students) {
        if (!seen.add(student.learnerId)) continue;
        await refreshChildMonitoringData(student.learnerId);
      }
    }
  }

  /// Pulls cloud learner activity into local SQLite for offline parent/teacher views.
  Future<void> _pullLearnerMonitoringCacheFromCloud(int learnerUserId) async {
    if (!CloudScope.syncMonitoring) return;
    if (await NetworkStatus.isOffline()) return;
    await FirebaseService.instance.initialize();
    await _notificationSync.initialize();
    if (!_notificationSync.isCloudAvailable) return;
    if (_user != null && (_user!.isParent || _user!.isTeacher)) {
      if (!await _ensureCloudAuthSession()) return;
    }
    final learnerFirebaseUid = await _resolveLearnerFirebaseUid(learnerUserId);
    if (learnerFirebaseUid == null || learnerFirebaseUid.isEmpty) {
      debugPrint(
        'Pull learner monitoring skipped: no Firebase UID for user $learnerUserId',
      );
      return;
    }
    try {
      final activities = await _notificationSync
          .getLearnerActivitiesFromCloud(
            learnerFirebaseUid: learnerFirebaseUid,
            rangeStart: MonitoringConstants.cloudActivityPullRangeStart(),
            rangeEnd: MonitoringConstants.cloudActivityPullRangeEnd(),
          )
          .timeout(const Duration(seconds: 30));
      debugPrint(
        'Pulled ${activities.length} learner activities for user $learnerUserId',
      );
      await _repo.mergeRemoteLearnerActivities(
        learnerUserId: learnerUserId,
        activities: activities,
      );
    } catch (e, st) {
      debugPrint('Pull learner monitoring cache failed: $e\n$st');
    }
  }

  Future<void> deleteHistoryItem(HistoryModel item) async {
    if (_user == null) return;
    _history.removeWhere((e) => e.id == item.id);
    notifyListeners();
    await _repo.removeHistory(item.id);
  }

  Future<void> clearAllHistory() async {
    if (_user == null) return;
    await _repo.clearHistory(_user!.id);
    _history = [];
    notifyListeners();
  }

  Future<void> _loadLinkedChildren({bool syncCloudInBackground = false}) async {
    if (_user == null || !_user!.isParent) {
      _linkedChildren = [];
      _selectedChildId = null;
      return;
    }
    if (syncCloudInBackground) {
      unawaited(_syncLinkedChildrenFromCloud());
    } else {
      await _syncLinkedChildrenFromCloud();
    }
    _linkedChildren = await _repo.getLinkedChildren(_user!.id);
    if (_linkedChildren.isEmpty) {
      _selectedChildId = null;
    } else if (_selectedChildId == null ||
        !_linkedChildren.any((c) => c.learnerId == _selectedChildId)) {
      _selectedChildId = _linkedChildren.first.learnerId;
    }
    await _loadNotifications();
    if (!syncCloudInBackground) {
      await _syncLinkedChildrenToCloud();
      await _startParentNotificationSync();
    }
  }

  /// Firebase UID for the signed-in account, waiting for auth restore when needed.
  Future<String?> _resolveAccountFirebaseUid() async {
    if (_user == null) return null;
    await FirebaseService.instance.initialize();
    await _notificationSync.initialize();

    var uid = _user!.firebaseUid ?? FirebaseService.instance.currentUid;
    uid ??= await FirebaseService.instance.waitForAuthUid(
      timeout: const Duration(seconds: 8),
    );
    if (uid == null || uid.isEmpty) return null;

    if (_user!.firebaseUid == null || _user!.firebaseUid!.isEmpty) {
      await _repo.linkFirebaseUid(_user!.id, uid);
      _user = _user!.copyWith(firebaseUid: uid);
    }
    return uid;
  }

  /// Parent/teacher Firestore reads require an active Firebase Auth session.
  Future<bool> _ensureCloudAuthSession() async {
    final uid = await _resolveAccountFirebaseUid();
    if (uid == null || uid.isEmpty) {
      debugPrint(
        'Cloud auth session missing for ${_user?.role ?? "unknown"}; '
        'monitoring sync needs online sign-in.',
      );
      return false;
    }
    return true;
  }

  /// Firebase UID for the signed-in parent, waiting for auth restore when needed.
  Future<String?> _resolveParentFirebaseUid() async {
    if (_user == null || !_user!.isParent) return null;
    return _resolveAccountFirebaseUid();
  }

  Future<void> _syncLinkedChildrenFromCloud() async {
    if (_user == null || !_user!.isParent) return;
    final parentFirebaseUid = await _resolveParentFirebaseUid();
    if (parentFirebaseUid == null) return;

    try {
      final links = await _notificationSync
          .getParentChildLinksFromCloud(parentFirebaseUid)
          .timeout(const Duration(seconds: 12));
      await _repo.mergeRemoteParentChildLinks(
        parentUserId: _user!.id,
        links: links,
      );
      for (final link in links) {
        final uid = link.learnerFirebaseUid.trim();
        if (uid.isEmpty) continue;
        final profile = await _notificationSync.getUserProfileFromCloud(uid);
        final remoteName = profile?.fullName.trim() ?? '';
        if (remoteName.isEmpty) continue;
        var learner = await _repo.findUserByFirebaseUid(uid);
        if (learner == null && link.learnerUserId > 0) {
          learner = await _repo.findUserById(link.learnerUserId);
        }
        if (learner != null && remoteName != learner.fullName) {
          await _repo.updateUserFullName(learner.id, remoteName);
        }
      }
    } catch (e, st) {
      debugPrint('Pull parent-child links failed: $e\n$st');
    }
  }

  Future<void> _syncLinkedChildrenToCloud() async {
    if (_user == null || !_user!.isParent || _linkedChildren.isEmpty) return;
    final parentFirebaseUid = await _resolveParentFirebaseUid();
    if (parentFirebaseUid == null) return;
    for (final child in _linkedChildren) {
      final learner = await _repo.findUserById(child.learnerId);
      final learnerFirebaseUid = learner?.firebaseUid;
      if (learnerFirebaseUid == null || learnerFirebaseUid.isEmpty) continue;
      await _notificationSync.syncParentChildLink(
        parentUserId: _user!.id,
        learnerUserId: child.learnerId,
        parentFirebaseUid: parentFirebaseUid,
        learnerFirebaseUid: learnerFirebaseUid,
        learnerName: child.fullName,
        learnerProfileCode: child.profileCode,
      );
    }
  }

  Future<void> _loadNotifications() async {
    if (_user == null || !_user!.isParent) {
      _notifications = [];
      return;
    }
    _notifications = await _repo.getParentNotifications(_user!.id);
  }

  Future<void> _startParentNotificationSync() async {
    if (_user == null || !_user!.isParent || !CloudScope.notifications) return;
    final firebaseUid = await _resolveParentFirebaseUid();
    if (firebaseUid == null) {
      debugPrint('Parent notification sync skipped: no Firebase UID.');
      return;
    }
    await _notificationSync.startParentSync(
      parentUserId: _user!.id,
      parentFirebaseUid: firebaseUid,
      onChanged: () async {
        await _loadNotifications();
        notifyListeners();
      },
    );
  }

  Future<void> _syncFirebaseSessionAfterRestore() async {
    if (_user == null || !FirebaseService.instance.isAvailable) return;
    final needsCloud = _user!.isTeacher ||
        _user!.isParent ||
        _user!.isOnlineAccount;
    if (!needsCloud) return;

    final restoredUid = await FirebaseService.instance.waitForAuthUid();
    final expected = _user!.firebaseUid;
    if (expected != null &&
        expected.isNotEmpty &&
        restoredUid != null &&
        restoredUid != expected) {
      debugPrint(
        'Firebase UID mismatch after restore (db=$expected, auth=$restoredUid).',
      );
    }
    if (expected != null &&
        expected.isNotEmpty &&
        restoredUid == null &&
        (_user!.isTeacher || _user!.isParent)) {
      debugPrint(
        'No Firebase session for ${_user!.role}; SMS/cloud need sign-in again.',
      );
    }
  }

  Future<UserModel> _linkFirebaseAccountIfAvailable({
    required UserModel user,
    required String email,
    required String password,
  }) async {
    if (!FirebaseService.instance.isAvailable) return user;
    final uid = await FirebaseService.instance.signInOrCreateAccount(
      email: email,
      password: password,
    );
    if (uid == null || user.firebaseUid == uid) return user;
    await _repo.linkFirebaseUid(user.id, uid);
    return user.copyWith(firebaseUid: uid);
  }

  Future<void> markNotificationRead(int notificationId) async {
    final remoteId = await _repo.notificationRemoteId(notificationId);
    await _repo.markNotificationRead(notificationId);
    if (remoteId != null) {
      unawaited(_notificationSync.markRemoteNotificationRead(remoteId));
    }
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index >= 0) {
      _notifications[index] =
          _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  Future<void> markAllNotificationsRead() async {
    if (_user == null || !_user!.isParent) return;
    final remoteIds =
        await _repo.unreadNotificationRemoteIds(_user!.id);
    await _repo.markAllNotificationsRead(_user!.id);
    if (remoteIds.isNotEmpty) {
      unawaited(_notificationSync.markAllRemoteNotificationsRead(remoteIds));
    }
    _notifications = [
      for (final n in _notifications) n.copyWith(isRead: true),
    ];
    notifyListeners();
  }

  Future<void> refreshNotifications() async {
    if (_user?.isParent == true && CloudScope.notifications) {
      await _startParentNotificationSync();
    }
    await _loadNotifications();
    notifyListeners();
  }

  Future<void> refreshLearnerCollections() async {
    await _refreshLearnerCollections();
    notifyListeners();
  }

  Future<void> refreshLinkedChildren({bool cloudSyncInBackground = true}) async {
    await _loadLinkedChildren(syncCloudInBackground: cloudSyncInBackground);
    if (!cloudSyncInBackground) {
      for (final child in _linkedChildren) {
        await refreshChildMonitoringData(child.learnerId);
      }
    }
    notifyListeners();
  }

  Future<void> refreshTeacherClasses({bool cloudSyncInBackground = true}) async {
    if (_user == null || !_user!.isTeacher) {
      _teacherClasses = [];
      _teacherStudentCount = 0;
      _teacherClassStudentCounts.clear();
      notifyListeners();
      return;
    }
    await _loadTeacherClasses();
    await _refreshTeacherClassCounts();
    notifyListeners();

    if (cloudSyncInBackground) {
      unawaited(_syncTeacherClassesFromCloudAndReload());
      return;
    }

    await _syncTeacherClassesFromCloud();
    await _loadTeacherClasses();
    await _refreshTeacherClassCounts();
    notifyListeners();
  }

  Future<void> _refreshTeacherClassCounts() async {
    if (_user == null || !_user!.isTeacher) return;
    _teacherClassStudentCounts
      ..clear()
      ..addEntries(
        await Future.wait(
          _teacherClasses.map((c) async {
            final count = await _repo.countStudentsInClass(c.id);
            return MapEntry(c.id, count);
          }),
        ),
      );
    _teacherStudentCount =
        await _repo.countEnrolledStudentsForTeacher(_user!.id);
  }

  Future<void> _syncTeacherClassesFromCloudAndReload() async {
    try {
      await _syncTeacherClassesFromCloud();
      await _loadTeacherClasses();
      await _refreshTeacherClassCounts();
      notifyListeners();
    } catch (e, st) {
      debugPrint('Teacher class background sync failed: $e\n$st');
    }
  }

  Future<int> getTeacherStudentCount() async {
    if (_user == null || !_user!.isTeacher) return 0;
    return _repo.countEnrolledStudentsForTeacher(_user!.id);
  }

  Future<int> countStudentsInClasses(List<int> classIds) async {
    if (_user == null || !_user!.isTeacher || classIds.isEmpty) return 0;
    return _repo.countStudentsInClasses(classIds);
  }

  Future<void> _syncTeacherClassesFromCloud() async {
    if (!CloudScope.syncMonitoring) return;
    if (_user == null || !_user!.isTeacher) return;
    if (!_notificationSync.isCloudAvailable) return;
    if (await NetworkStatus.isOffline()) return;
    if (NetworkStatus.isCloudBlocked) return;

    final teacherFirebaseUid =
        _user!.firebaseUid ?? FirebaseService.instance.currentUid;
    if (teacherFirebaseUid == null || teacherFirebaseUid.isEmpty) return;

    try {
      final localClasses = await _repo.getTeacherClasses(_user!.id);
      for (final teacherClass in localClasses) {
        await _notificationSync.syncTeacherClass(
          classCode: teacherClass.code,
          className: teacherClass.name,
          teacherFirebaseUid: teacherFirebaseUid,
          teacherUserId: _user!.id,
          createdAt: DateTime.now(),
        );
      }

      final remoteClasses = await _notificationSync
          .getTeacherClassesFromCloud(teacherFirebaseUid)
          .timeout(const Duration(seconds: 12));
      await _repo.mergeRemoteTeacherClasses(
        teacherUserId: _user!.id,
        remoteClasses: remoteClasses,
        skipClassCodes: _deletedClassCodes,
      );
      final remoteClassCodes = remoteClasses
          .map((c) => AppRepository.normalizeClassCode(c.classCode))
          .where(AppRepository.isValidClassCodeFormat)
          .toSet();
      await _repo.pruneStaleTeacherClasses(
        teacherUserId: _user!.id,
        remoteClassCodes: remoteClassCodes,
        skipClassCodes: _deletedClassCodes,
      );

      final enrollments = await _notificationSync
          .getClassEnrollmentsFromCloud(teacherFirebaseUid)
          .timeout(const Duration(seconds: 12));
      await _repo.mergeRemoteEnrollmentsForTeacher(
        teacherUserId: _user!.id,
        enrollments: enrollments,
      );

      // Merge cloud lessons into local, then re-push so all devices stay in sync.
      for (final teacherClass in localClasses) {
        await _syncClassLessonsFromCloud(
          classId: teacherClass.id,
          classCode: teacherClass.code,
        );
        await _pushClassContentToCloud(teacherClass.id);
      }
    } catch (e, st) {
      debugPrint('Teacher class cloud sync failed: $e\n$st');
    }
  }

  Future<void> _pushTeacherClassToCloud({
    required String classCode,
    required String className,
  }) async {
    if (!CloudScope.syncMonitoring) return;
    if (_user == null || !_user!.isTeacher) return;
    final teacherFirebaseUid =
        _user!.firebaseUid ?? FirebaseService.instance.currentUid;
    if (teacherFirebaseUid == null || teacherFirebaseUid.isEmpty) return;

    await _notificationSync.syncTeacherClass(
      classCode: classCode,
      className: className,
      teacherFirebaseUid: teacherFirebaseUid,
      teacherUserId: _user!.id,
      createdAt: DateTime.now(),
    );
  }

  Future<List<TeacherRecentAlert>> getTeacherRecentAlerts({int limit = 4}) async {
    if (_user == null || !_user!.isTeacher) return [];
    return _repo.getRecentAlertsForTeacher(
      teacherUserId: _user!.id,
      limit: limit,
    );
  }

  Future<List<TeacherRecentAlert>> getTeacherAlertHistory({int limit = 100}) async {
    if (_user == null || !_user!.isTeacher) return [];
    return _repo.getRecentAlertsForTeacher(
      teacherUserId: _user!.id,
      limit: limit,
    );
  }

  Future<List<TeacherRecentLesson>> getTeacherRecentLessons({int limit = 8}) async {
    if (_user == null || !_user!.isTeacher) return [];
    return _repo.getRecentLessonsForTeacher(
      teacherUserId: _user!.id,
      limit: limit,
    );
  }

  void selectChild(int learnerId) {
    if (_linkedChildren.any((c) => c.learnerId == learnerId)) {
      _selectedChildId = learnerId;
      notifyListeners();
    }
  }

  Future<String?> linkChildByProfileCode(String code) async {
    if (_user == null || !_user!.isParent) {
      return AppStrings.notSignedIn(_language);
    }
    final normalized = AppRepository.normalizeProfileCode(code);
    if (!AppRepository.isValidProfileCodeFormat(normalized)) {
      return AppStrings.invalidProfileCode(_language);
    }

    await FirebaseService.instance.initialize();
    await _notificationSync.initialize();

    var learner = await _repo.findLearnerByProfileCode(normalized);
    if (learner == null &&
        CloudScope.syncMonitoring &&
        _notificationSync.isCloudAvailable) {
      if (FirebaseService.instance.currentUid == null) {
        return AppStrings.loginNeedsInternet(_language);
      }
      try {
        final remote = await _notificationSync
            .findLearnerProfileByCodeFromCloud(normalized)
            .timeout(const Duration(seconds: 12));
        if (remote != null) {
          learner = await _repo.ensureLearnerFromRemoteProfile(remote);
        }
      } catch (e, st) {
        debugPrint('Cloud profile code lookup failed: $e\n$st');
      }
    }
    if (learner == null) {
      return AppStrings.childNotFound(_language);
    }
    if (learner.id == _user!.id) {
      return AppStrings.cannotLinkSelf(_language);
    }
    if (await _repo.isChildLinked(_user!.id, learner.id)) {
      return AppStrings.childAlreadyLinked(_language);
    }
    await _repo.linkParentToChild(_user!.id, learner.id);
    final parentFirebaseUid =
        _user!.firebaseUid ?? FirebaseService.instance.currentUid;
    final learnerFirebaseUid = await _resolveLearnerFirebaseUid(learner.id);
    if (parentFirebaseUid != null &&
        parentFirebaseUid.isNotEmpty &&
        learnerFirebaseUid != null &&
        learnerFirebaseUid.isNotEmpty) {
      final profileCode = await _repo.ensureLearnerProfileCode(learner.id);
      await _notificationSync.syncParentChildLink(
        parentUserId: _user!.id,
        learnerUserId: learner.id,
        parentFirebaseUid: parentFirebaseUid,
        learnerFirebaseUid: learnerFirebaseUid,
        learnerName: learner.fullName,
        learnerProfileCode: profileCode,
      );
    }
    await _loadLinkedChildren();
    _selectedChildId = learner.id;
    notifyListeners();
    await refreshChildMonitoringData(learner.id);
    return null;
  }

  Future<String?> unlinkChild(int learnerId) async {
    if (_user == null || !_user!.isParent) {
      return AppStrings.notSignedIn(_language);
    }
    final learner = await _repo.findUserById(learnerId);
    final parentFirebaseUid =
        _user!.firebaseUid ?? FirebaseService.instance.currentUid;
    final learnerFirebaseUid = learner?.firebaseUid;
    await _repo.unlinkParentChild(_user!.id, learnerId);
    if (parentFirebaseUid != null &&
        parentFirebaseUid.isNotEmpty &&
        learnerFirebaseUid != null &&
        learnerFirebaseUid.isNotEmpty) {
      await _notificationSync.unsyncParentChildLink(
        parentFirebaseUid: parentFirebaseUid,
        learnerFirebaseUid: learnerFirebaseUid,
      );
    }
    await _loadLinkedChildren();
    notifyListeners();
    return null;
  }

  Future<void> _loadTeacherClasses() async {
    if (_user == null || !_user!.isTeacher) {
      _teacherClasses = [];
      return;
    }
    _teacherClasses = await _repo.getTeacherClasses(_user!.id);
  }

  Future<String?> createTeacherClass(String className) async {
    if (_user == null || !_user!.isTeacher) {
      return AppStrings.notSignedIn(_language);
    }
    final result = await _repo.createTeacherClass(
      teacherUserId: _user!.id,
      className: className,
    );
    if (result.error == 'empty') {
      return AppStrings.enterClassName(_language);
    }
    await _pushTeacherClassToCloud(
      classCode: result.code,
      className: result.name,
    );
    await refreshTeacherClasses();
    return null;
  }

  Future<String?> deleteTeacherClass(int classId) async {
    if (_user == null || !_user!.isTeacher) {
      return AppStrings.notSignedIn(_language);
    }
    final classRow = await _repo.findClassById(classId);
    final classCode = classRow?['class_code'] as String?;
    final ok = await _repo.deleteTeacherClass(
      teacherUserId: _user!.id,
      classId: classId,
    );
    if (!ok) return AppStrings.classNotFound(_language);
    if (classCode != null && classCode.isNotEmpty) {
      _deletedClassCodes.add(AppRepository.normalizeClassCode(classCode));
      await _notificationSync.removeTeacherClass(classCode: classCode);
    }
    await refreshTeacherClasses();
    return null;
  }

  Future<bool> updateTeacherClassName(int classId, String className) async {
    if (_user == null || !_user!.isTeacher) return false;
    final trimmed = className.trim();
    final classRow = await _repo.findClassById(classId);
    final ok = await _repo.updateTeacherClassName(
      teacherUserId: _user!.id,
      classId: classId,
      className: trimmed,
    );
    if (ok) {
      final classCode = classRow?['class_code'] as String?;
      if (classCode != null && classCode.isNotEmpty) {
        await _pushTeacherClassToCloud(
          classCode: classCode,
          className: trimmed,
        );
        await _resyncClassEnrollmentsToCloud(classId: classId);
      }
    }
    await refreshTeacherClasses();
    return ok;
  }

  Future<void> _resyncClassEnrollmentsToCloud({required int classId}) async {
    if (!CloudScope.syncMonitoring || _user == null || !_user!.isTeacher) {
      return;
    }
    if (!_notificationSync.isCloudAvailable) return;
    final teacherFirebaseUid =
        _user!.firebaseUid ?? FirebaseService.instance.currentUid;
    if (teacherFirebaseUid == null || teacherFirebaseUid.isEmpty) return;

    final classRow = await _repo.findClassById(classId);
    if (classRow == null) return;
    final classCode = (classRow['class_code'] as String?) ?? '';
    final className = (classRow['class_name'] as String?) ?? '';
    if (classCode.isEmpty) return;

    final students = await _repo.getTeacherClassStudentsForClass(
      teacherUserId: _user!.id,
      classId: classId,
    );
    for (final student in students) {
      final learnerFirebaseUid =
          await _repo.getFirebaseUidForUser(student.learnerId);
      if (learnerFirebaseUid == null || learnerFirebaseUid.isEmpty) continue;
      await _notificationSync.syncClassEnrollment(
        classId: classId,
        classCode: classCode,
        className: className,
        teacherFirebaseUid: teacherFirebaseUid,
        learnerUserId: student.learnerId,
        learnerName: student.fullName,
        learnerFirebaseUid: learnerFirebaseUid,
      );
    }
  }

  Future<int> studentCountForClass(int classId) async {
    if (_teacherClassStudentCounts.containsKey(classId)) {
      return _teacherClassStudentCounts[classId]!;
    }
    return _repo.countStudentsInClass(classId);
  }

  Future<List<ClassLesson>> getClassLessons(
    int classId, {
    bool cloudSyncInBackground = true,
  }) async {
    if (_user == null || !_user!.isTeacher) return [];
    final lessons = await _repo.getClassLessons(
      teacherUserId: _user!.id,
      classId: classId,
    );
    if (cloudSyncInBackground) {
      unawaited(_pushClassContentToCloud(classId));
    } else {
      await _pushClassContentToCloud(classId);
    }
    return lessons;
  }

  Future<List<ClassLesson>> getEnrolledClassLessons(
    int classId, {
    bool cloudSyncInBackground = true,
  }) async {
    if (_user == null || !_user!.isLearner) return [];
    final classRow = await _repo.findClassById(classId);
    final classCode = (classRow?['class_code'] as String?) ?? '';
    final lessons = await _repo.getEnrolledClassLessons(
      learnerUserId: _user!.id,
      classId: classId,
    );
    if (classCode.isEmpty) return lessons;
    if (cloudSyncInBackground) {
      unawaited(_syncEnrolledClassLessonsFromCloudAndReload(classId, classCode));
      return lessons;
    }
    await _syncClassLessonsFromCloud(
      classId: classId,
      classCode: classCode,
    );
    return _repo.getEnrolledClassLessons(
      learnerUserId: _user!.id,
      classId: classId,
    );
  }

  Future<void> _syncEnrolledClassLessonsFromCloudAndReload(
    int classId,
    String classCode,
  ) async {
    try {
      await _syncClassLessonsFromCloud(
        classId: classId,
        classCode: classCode,
      );
      notifyListeners();
    } catch (e, st) {
      debugPrint('Background lesson sync failed: $e\n$st');
    }
  }

  /// Local lessons first, then optional cloud lesson merge for teacher class detail.
  Future<List<ClassLesson>> getTeacherClassLessonsForDisplay(
    int classId, {
    bool cloudSyncInBackground = true,
  }) async {
    if (_user == null || !_user!.isTeacher) return [];
    final lessons = await _repo.getClassLessons(
      teacherUserId: _user!.id,
      classId: classId,
    );
    final classRow = await _repo.findClassById(classId);
    final classCode = (classRow?['class_code'] as String?) ?? '';
    if (classCode.isEmpty) return lessons;
    if (cloudSyncInBackground) {
      unawaited(_syncTeacherClassLessonsFromCloudAndReload(classId, classCode));
      return lessons;
    }
    await _syncClassLessonsFromCloud(classId: classId, classCode: classCode);
    return _repo.getClassLessons(
      teacherUserId: _user!.id,
      classId: classId,
    );
  }

  Future<void> _syncTeacherClassLessonsFromCloudAndReload(
    int classId,
    String classCode,
  ) async {
    try {
      await _syncClassLessonsFromCloud(
        classId: classId,
        classCode: classCode,
      );
      notifyListeners();
    } catch (e, st) {
      debugPrint('Background teacher lesson sync failed: $e\n$st');
    }
  }

  Future<List<LessonPhrase>> getEnrolledLessonPhrases(
    int lessonId, {
    bool cloudSyncInBackground = true,
  }) async {
    if (_user == null || !_user!.isLearner) return [];
    final classId = await _repo.classIdForLesson(lessonId);
    if (classId != null) {
      final classRow = await _repo.findClassById(classId);
      final classCode = (classRow?['class_code'] as String?) ?? '';
      if (classCode.isNotEmpty && cloudSyncInBackground) {
        unawaited(_syncClassLessonsFromCloud(
          classId: classId,
          classCode: classCode,
        ));
      } else if (classCode.isNotEmpty) {
        await _syncClassLessonsFromCloud(
          classId: classId,
          classCode: classCode,
        );
      }
    }
    return _repo.getEnrolledLessonPhrases(
      learnerUserId: _user!.id,
      lessonId: lessonId,
    );
  }

  Future<ClassLesson?> createClassLesson(int classId, String title) async {
    if (_user == null || !_user!.isTeacher) return null;
    final lesson = await _repo.createClassLesson(
      teacherUserId: _user!.id,
      classId: classId,
      title: title.trim(),
    );
    if (lesson != null) {
      await _pushClassContentToCloud(classId);
    }
    return lesson;
  }

  Future<bool> updateClassLesson(int lessonId, String title) async {
    if (_user == null || !_user!.isTeacher) return false;
    final classId = await _repo.classIdForLesson(lessonId);
    final updated = await _repo.updateClassLesson(
      teacherUserId: _user!.id,
      lessonId: lessonId,
      title: title.trim(),
    );
    if (updated && classId != null) {
      await _pushClassContentToCloud(classId);
    }
    return updated;
  }

  Future<bool> deleteClassLesson(int lessonId) async {
    if (_user == null || !_user!.isTeacher) return false;
    final classId = await _repo.classIdForLesson(lessonId);
    final deleted = await _repo.deleteClassLesson(
      teacherUserId: _user!.id,
      lessonId: lessonId,
    );
    if (deleted && classId != null) {
      await _pushClassContentToCloud(classId);
    }
    return deleted;
  }

  Future<List<LessonPhrase>> getLessonPhrases(int lessonId) async {
    if (_user == null || !_user!.isTeacher) return [];
    return _repo.getLessonPhrases(
      teacherUserId: _user!.id,
      lessonId: lessonId,
    );
  }

  Future<String?> addLessonPhrase(
    int lessonId,
    String text, {
    String? imagePath,
  }) async {
    if (_user == null || text.trim().isEmpty) return null;
    final saved = await persistPhraseImageIfNeeded(imagePath);
    final classId = await _repo.classIdForLesson(lessonId);
    final phrase = await _repo.addLessonPhrase(
      teacherUserId: _user!.id,
      lessonId: lessonId,
      text: text.trim(),
      imagePath: saved,
    );
    if (phrase != null && classId != null) {
      await _pushClassContentToCloud(classId);
    }
    return phrase == null ? AppStrings.unableAddPhrase(_language) : null;
  }

  Future<void> deleteLessonPhrase(int phraseId) async {
    if (_user == null || !_user!.isTeacher) return;
    final classId = await _repo.classIdForLessonPhrase(phraseId);
    await _repo.deleteLessonPhrase(
      teacherUserId: _user!.id,
      phraseId: phraseId,
    );
    if (classId != null) {
      await _pushClassContentToCloud(classId);
    }
  }

  Future<bool> updateLessonPhrase(
    int phraseId, {
    required String text,
    String? imagePath,
    required bool clearImage,
  }) async {
    if (_user == null || !_user!.isTeacher) return false;
    final savedImage =
        clearImage ? null : await persistPhraseImageIfNeeded(imagePath);
    final classId = await _repo.classIdForLessonPhrase(phraseId);
    final updated = await _repo.updateLessonPhrase(
      teacherUserId: _user!.id,
      phraseId: phraseId,
      text: text,
      imagePath: savedImage,
    );
    if (updated && classId != null) {
      await _pushClassContentToCloud(classId);
    }
    return updated;
  }

  Future<void> _pushClassContentToCloud(int classId) async {
    if (!CloudScope.syncMonitoring) return;
    if (_user == null || !_user!.isTeacher || !_notificationSync.isCloudAvailable) {
      return;
    }
    final classRow = await _repo.findClassById(classId);
    if (classRow == null) return;
    final classCode = (classRow['class_code'] as String?) ?? '';
    final className = (classRow['class_name'] as String?) ?? '';
    final teacherFirebaseUid =
        _user!.firebaseUid ??
        await FirebaseService.instance.waitForAuthUid() ??
        FirebaseService.instance.currentUid;
    if (classCode.isEmpty ||
        className.isEmpty ||
        teacherFirebaseUid == null ||
        teacherFirebaseUid.isEmpty) {
      return;
    }
    try {
      final content = await _repo.buildRemoteClassContent(
        teacherUserId: _user!.id,
        classId: classId,
        classCode: classCode,
        className: className,
        teacherFirebaseUid: teacherFirebaseUid,
      );
      if (content == null) return;
      // Never overwrite cloud lessons with an empty local copy.
      if (content.lessons.isEmpty) {
        final existing = await _notificationSync
            .getClassContentFromCloud(classCode)
            .timeout(const Duration(seconds: 8));
        if (existing != null && existing.lessons.isNotEmpty) return;
      }
      await _notificationSync.syncClassContent(content);
    } catch (e, st) {
      debugPrint('Push class content to cloud failed: $e\n$st');
    }
  }

  Future<void> _syncClassLessonsFromCloud({
    required int classId,
    required String classCode,
  }) async {
    if (!CloudScope.syncMonitoring) return;
    if (!_notificationSync.isCloudAvailable) return;
    final normalized = AppRepository.normalizeClassCode(classCode);
    if (!AppRepository.isValidClassCodeFormat(normalized)) return;
    try {
      final remote = await _notificationSync
          .getClassContentFromCloud(normalized)
          .timeout(const Duration(seconds: 12));
      if (remote == null) {
        debugPrint('No cloud content for class $normalized');
        return;
      }
      if (remote.lessons.isEmpty) {
        debugPrint('Cloud class $normalized has no lessons yet');
        return;
      }
      await _repo.mergeRemoteClassContent(classId: classId, content: remote);
    } catch (e, st) {
      debugPrint('Sync class lessons from cloud failed: $e\n$st');
    }
  }

  /// Pull latest lessons/phrases from cloud for an enrolled class (learner).
  Future<void> refreshEnrolledClassLessons(int classId) async {
    if (_user == null || !_user!.isLearner) return;
    final classRow = await _repo.findClassById(classId);
    final classCode = (classRow?['class_code'] as String?) ?? '';
    if (classCode.isEmpty) return;
    await _syncClassLessonsFromCloud(classId: classId, classCode: classCode);
  }

  /// Returns the roster for a class, merging cloud enrollments into local SQLite
  /// so students enrolled from another device appear on the teacher's phone too.
  Future<List<TeacherClassStudent>> getTeacherClassStudentsForClass(
    int classId, {
    bool cloudSyncInBackground = true,
  }) async {
    if (_user == null || !_user!.isTeacher) return [];
    final local = await _repo.getTeacherClassStudentsForClass(
      teacherUserId: _user!.id,
      classId: classId,
    );
    if (cloudSyncInBackground) {
      unawaited(_syncTeacherClassesFromCloud());
      return local;
    }
    await _syncTeacherClassesFromCloud();
    return _repo.getTeacherClassStudentsForClass(
      teacherUserId: _user!.id,
      classId: classId,
    );
  }

  Future<List<TeacherClassStudent>> getTeacherClassStudents() async {
    if (_user == null || !_user!.isTeacher) return [];
    if (CloudScope.syncMonitoring &&
        !await NetworkStatus.isOffline() &&
        !NetworkStatus.isCloudBlocked) {
      await FirebaseService.instance.initialize();
      await _notificationSync.initialize();
      if (_notificationSync.isCloudAvailable) {
        await _syncTeacherClassesFromCloud();
      }
    }
    final students = await _repo.getTeacherClassStudents(_user!.id);
    _scheduleTeacherEnrollmentCloudSync(students);
    return students;
  }

  /// Background Firestore sync for SMS authorization (does not block UI).
  void scheduleTeacherEnrollmentCloudSyncForClass(int classId) {
    if (_user == null || !_user!.isTeacher) return;
    unawaited(() async {
      final students = await _repo.getTeacherClassStudentsForClass(
        teacherUserId: _user!.id,
        classId: classId,
      );
      _scheduleTeacherEnrollmentCloudSync(students);
    }());
  }

  void _scheduleTeacherEnrollmentCloudSync(List<TeacherClassStudent> students) {
    if (students.isEmpty) return;
    final teacherFirebaseUid =
        _user?.firebaseUid ?? FirebaseService.instance.currentUid;
    if (teacherFirebaseUid == null || teacherFirebaseUid.isEmpty) return;
    unawaited(
      _syncLocalEnrollmentsToCloud(
        students,
        teacherFirebaseUid: teacherFirebaseUid,
      ),
    );
  }

  Future<void> _syncLocalEnrollmentsToCloud(
    List<TeacherClassStudent> students, {
    required String teacherFirebaseUid,
  }) async {
    if (!CloudScope.syncMonitoring) return;
    if (!_notificationSync.isCloudAvailable) return;
    try {
      for (final student in students) {
        final learnerFirebaseUid =
            await _repo.getFirebaseUidForUser(student.learnerId);
        if (learnerFirebaseUid == null || learnerFirebaseUid.isEmpty) continue;
        await _notificationSync.syncClassEnrollment(
          classId: student.classId,
          classCode: student.classCode,
          className: student.className,
          teacherFirebaseUid: teacherFirebaseUid,
          learnerUserId: student.learnerId,
          learnerName: student.fullName,
          learnerFirebaseUid: learnerFirebaseUid,
        );
      }
    } catch (e, st) {
      debugPrint('Cloud enrollment sync failed: $e\n$st');
    }
  }

  Future<TeacherAlertDeliveryResult> sendTeacherAlert({
    required int learnerUserId,
    required String learnerName,
    required int classId,
    required String className,
    required ParentAlertType alertType,
  }) async {
    if (_user == null || !_user!.isTeacher) {
      return TeacherAlertDeliveryResult(
        inAppError: AppStrings.notSignedIn(_language),
        sms: SmsAlertResult.empty,
      );
    }

    final title = AppStrings.teacherAlertTitle(
      _language,
      _user!.fullName,
      learnerName,
      alertType,
    );
    final body = AppStrings.teacherAlertBody(
      _language,
      _user!.fullName,
      className,
      learnerName,
      alertType,
    );

    await FirebaseService.instance.initialize();
    await _notificationSync.initialize();

    final result = await _notificationSync.sendTeacherAlert(
      teacherUserId: _user!.id,
      teacherName: _user!.fullName,
      learnerUserId: learnerUserId,
      learnerName: learnerName,
      classId: classId,
      className: className,
      alertType: alertType,
      title: title,
      body: body,
    );

    final inAppError = switch (result.status) {
      TeacherAlertStatus.sent => null,
      TeacherAlertStatus.noLinkedParents =>
        AppStrings.alertNoLinkedParents(_language, learnerName),
      TeacherAlertStatus.notAuthorized =>
        AppStrings.alertNotAuthorized(_language),
    };

    if (result.notificationIds.isNotEmpty) {
      _teacherAlertsRevision++;
      notifyListeners();
    }

    final learnerFirebaseUid =
        await _resolveLearnerFirebaseUid(learnerUserId);
    final localContacts =
        await _repo.getEmergencyContactsForLearner(learnerUserId);
    var contacts = CloudScope.syncMonitoring
        ? await _notificationSync.resolveEmergencyContacts(
            learnerUserId: learnerUserId,
            localContacts: localContacts,
            learnerFirebaseUid: learnerFirebaseUid,
          )
        : localContacts;
    contacts = AppRepository.normalizeEmergencyContacts(contacts);
    debugPrint(
      'Teacher alert SMS: ${contacts.length} emergency contact(s) for '
      'learner $learnerUserId (uid=${learnerFirebaseUid ?? "none"})',
    );
    // Keep SMS short (single-part) for reliable delivery on budget Android phones.
    final smsText = '[TapTalk] $title ($className)';

    if (contacts.isEmpty) {
      return TeacherAlertDeliveryResult(
        inAppError: inAppError,
        sms: SmsAlertResult(
          attempted: 0,
          sent: 0,
          failed: 0,
          errorMessage: AppStrings.smsNoEmergencyContacts(_language),
        ),
      );
    }

    final offline = await NetworkStatus.isOffline();
    final sms = await _deviceSms.sendEmergencyAlert(
      language: _language,
      rawContacts: contacts,
      message: smsText,
    );

    return TeacherAlertDeliveryResult(
      inAppError: inAppError ??
          (offline ? AppStrings.inAppNeedsInternet(_language) : null),
      sms: SmsAlertResult(
        attempted: sms.attempted,
        sent: sms.sent,
        failed: sms.failed,
        invalidContacts: sms.invalidContacts,
        errorMessage: sms.errorMessage,
        sentViaDevice: true,
        openedComposer: sms.openedComposer,
      ),
    );
  }

  Future<void> _loadEnrolledClasses() async {
    if (_user == null || !_user!.isLearner) {
      _enrolledClasses = [];
      return;
    }
    _enrolledClasses = await _repo.getEnrolledClasses(_user!.id);
    // Push only enrollments whose class still exists on cloud, then pull/prune.
    // Pushing blindly would re-create enrollments the teacher already deleted.
    await _resyncLearnerEnrollmentsToCloud();
    await _syncEnrolledClassesFromCloud();
    _enrolledClasses = await _repo.getEnrolledClasses(_user!.id);
  }

  /// Pulls cloud enrollment records for this learner and imports any missing
  /// teacher-class records into local SQLite so the learner sees them.
  Future<void> _syncEnrolledClassesFromCloud() async {
    if (!CloudScope.syncMonitoring) return;
    if (_user == null || !_user!.isLearner || !_notificationSync.isCloudAvailable) {
      return;
    }
    final uid = await _learnerFirebaseUidForSync();
    if (uid == null || uid.isEmpty) return;
    try {
      final remoteEnrollments = await _notificationSync
          .getClassEnrollmentsForLearnerFromCloud(uid)
          .timeout(const Duration(seconds: 12));
      await _applyRemoteEnrollmentsForLearner(
        learnerUserId: _user!.id,
        remoteEnrollments: remoteEnrollments,
      );
    } catch (e, st) {
      debugPrint('Sync enrolled classes from cloud failed: $e\n$st');
    }
  }

  Future<void> _applyRemoteEnrollmentsForLearner({
    required int learnerUserId,
    required List<RemoteClassEnrollment> remoteEnrollments,
  }) async {
    final remoteClassCodes = <String>{};
    for (final enrollment in remoteEnrollments) {
      final code = AppRepository.normalizeClassCode(enrollment.classCode);
      if (!AppRepository.isValidClassCodeFormat(code)) continue;
      remoteClassCodes.add(code);

      var classRow = await _repo.findClassByCode(code);
      if (classRow == null) {
        final remoteClass = await _notificationSync
            .getTeacherClassByCodeFromCloud(code)
            .timeout(const Duration(seconds: 8));
        if (remoteClass != null) {
          classRow =
              await _repo.importRemoteTeacherClassForEnrollment(remoteClass);
        }
      }
      if (classRow == null) continue;

      final classId = classRow['id'] as int;
      final enrollmentName = enrollment.className.trim();
      if (enrollmentName.isNotEmpty) {
        await _repo.updateClassDisplayName(
          classId: classId,
          className: enrollmentName,
        );
      } else {
        final remoteClass = await _notificationSync
            .getTeacherClassByCodeFromCloud(code)
            .timeout(const Duration(seconds: 8));
        final cloudName = remoteClass?.className.trim() ?? '';
        if (cloudName.isNotEmpty) {
          await _repo.updateClassDisplayName(
            classId: classId,
            className: cloudName,
          );
        }
      }

      if (!await _repo.isLearnerEnrolled(learnerUserId, classId)) {
        await _repo.enrollLearnerInClass(learnerUserId, classId);
      }
      await _syncClassLessonsFromCloud(classId: classId, classCode: code);
    }

    await _repo.pruneStaleEnrollmentsForLearner(
      learnerUserId: learnerUserId,
      remoteClassCodes: remoteClassCodes,
    );
    await _pruneEnrollmentsForDeletedCloudClasses(learnerUserId);
  }

  /// Drops local enrollments when the teacher removed the class from cloud.
  Future<void> _pruneEnrollmentsForDeletedCloudClasses(int learnerUserId) async {
    if (!CloudScope.syncMonitoring || !_notificationSync.isCloudAvailable) return;
    final local = await _repo.getEnrolledClasses(learnerUserId);
    for (final enrolled in local) {
      final code = AppRepository.normalizeClassCode(enrolled.classCode);
      if (!AppRepository.isValidClassCodeFormat(code)) continue;
      try {
        final remoteClass = await _notificationSync
            .getTeacherClassByCodeFromCloud(code)
            .timeout(const Duration(seconds: 8));
        if (remoteClass == null) {
          await _repo.unenrollLearnerFromClass(learnerUserId, enrolled.classId);
        }
      } catch (e, st) {
        debugPrint('Deleted-class prune lookup failed: $e\n$st');
      }
    }
  }

  Future<void> _resyncLearnerEnrollmentsToCloud() async {
    if (!CloudScope.syncMonitoring) return;
    if (_user == null || !_user!.isLearner || !_notificationSync.isCloudAvailable) {
      return;
    }
    final learnerFirebaseUid = await _learnerFirebaseUidForSync();
    if (learnerFirebaseUid == null || learnerFirebaseUid.isEmpty) return;

    for (final enrolled in _enrolledClasses) {
      final code = AppRepository.normalizeClassCode(enrolled.classCode);
      RemoteTeacherClass? remoteClass;
      try {
        remoteClass = await _notificationSync
            .getTeacherClassByCodeFromCloud(code)
            .timeout(const Duration(seconds: 8));
      } catch (e, st) {
        debugPrint('Skip enrollment resync; class lookup failed: $e\n$st');
        continue;
      }
      // Teacher deleted this class — do not re-create the cloud enrollment.
      if (remoteClass == null) continue;

      final teacherFirebaseUid = remoteClass.teacherFirebaseUid.trim().isNotEmpty
          ? remoteClass.teacherFirebaseUid.trim()
          : await _repo.getFirebaseUidForUser(enrolled.teacherId);
      if (teacherFirebaseUid == null || teacherFirebaseUid.isEmpty) continue;
      await _notificationSync.syncClassEnrollment(
        classId: enrolled.classId,
        classCode: code,
        className: enrolled.className,
        teacherFirebaseUid: teacherFirebaseUid,
        learnerUserId: _user!.id,
        learnerName: _user!.fullName,
        learnerFirebaseUid: learnerFirebaseUid,
      );
    }
  }

  Future<String?> enrollByClassCode(String code) async {
    if (_user == null || !_user!.isLearner) {
      return AppStrings.notSignedIn(_language);
    }
    final normalized = AppRepository.normalizeClassCode(code);
    if (!AppRepository.isValidClassCodeFormat(normalized)) {
      return AppStrings.invalidClassCode(_language);
    }
    var classRow = await _repo.findClassByCode(normalized);
    String? teacherFirebaseUidFromRemote;
    if (classRow == null) {
      if (!_notificationSync.isCloudAvailable) {
        return AppStrings.classNotFound(_language);
      }
      try {
        final remote = await _notificationSync
            .getTeacherClassByCodeFromCloud(normalized)
            .timeout(const Duration(seconds: 12));
        if (remote != null) {
          teacherFirebaseUidFromRemote = remote.teacherFirebaseUid;
          classRow = await _repo.importRemoteTeacherClassForEnrollment(remote);
        }
      } catch (e, st) {
        debugPrint('Cloud class code lookup failed: $e\n$st');
      }
      if (classRow == null) {
        return AppStrings.classNotFound(_language);
      }
    }
    final classId = classRow['id'] as int;
    final alreadyEnrolled =
        await _repo.isLearnerEnrolled(_user!.id, classId);
    if (!alreadyEnrolled) {
      await _repo.enrollLearnerInClass(_user!.id, classId);
    }
    // Always pull lessons from cloud (even if already enrolled).
    await _syncClassLessonsFromCloud(classId: classId, classCode: normalized);
    if (alreadyEnrolled) {
      await _loadEnrolledClasses();
      return AppStrings.classAlreadyEnrolled(_language);
    }
    final learnerFirebaseUid =
        _user!.firebaseUid ?? FirebaseService.instance.currentUid;
    final teacherUserId = classRow['teacher_user_id'] as int?;
    final teacherFirebaseUid = teacherFirebaseUidFromRemote ??
        (teacherUserId == null
            ? null
            : await _repo.getFirebaseUidForUser(teacherUserId));
    if (learnerFirebaseUid != null &&
        learnerFirebaseUid.isNotEmpty &&
        teacherFirebaseUid != null &&
        teacherFirebaseUid.isNotEmpty) {
      await _notificationSync.syncClassEnrollment(
        classId: classId,
        classCode: (classRow['class_code'] as String?) ?? '',
        className: (classRow['class_name'] as String?) ?? '',
        teacherFirebaseUid: teacherFirebaseUid,
        learnerUserId: _user!.id,
        learnerName: _user!.fullName,
        learnerFirebaseUid: learnerFirebaseUid,
      );
    }
    await _loadEnrolledClasses();
    return null;
  }

  /// Reload enrolled classes from DB; optionally merge cloud enrollments in background.
  Future<void> refreshEnrolledClasses({
    bool cloudSyncInBackground = true,
  }) async {
    if (_user == null || !_user!.isLearner) {
      _enrolledClasses = [];
      notifyListeners();
      return;
    }
    await _loadEnrolledClasses();
    notifyListeners();
    if (cloudSyncInBackground) {
      unawaited(_syncEnrolledClassesFromCloudAndReload());
      return;
    }
    await _syncEnrolledClassesFromCloud();
    await _loadEnrolledClasses();
    notifyListeners();
  }

  Future<void> _syncEnrolledClassesFromCloudAndReload() async {
    try {
      await _syncEnrolledClassesFromCloud();
      await _loadEnrolledClasses();
      notifyListeners();
    } catch (e, st) {
      debugPrint('Background enrolled-class sync failed: $e\n$st');
    }
  }

  /// Call after UI that triggered enroll has closed (avoids rebuild during dialog).
  Future<void> notifyEnrolledClassesChanged() => refreshEnrolledClasses();

  Future<String?> leaveClass(int classId) async {
    if (_user == null || !_user!.isLearner) {
      return AppStrings.notSignedIn(_language);
    }
    final classRow = await _repo.findClassById(classId);
    final classCode = (classRow?['class_code'] as String?) ?? '';
    final learnerFirebaseUid =
        _user!.firebaseUid ?? FirebaseService.instance.currentUid;
    await _repo.unenrollLearnerFromClass(_user!.id, classId);
    if (classCode.isNotEmpty &&
        learnerFirebaseUid != null &&
        learnerFirebaseUid.isNotEmpty) {
      await _notificationSync.unsyncClassEnrollment(
        classCode: classCode,
        learnerFirebaseUid: learnerFirebaseUid,
      );
    }
    await _loadEnrolledClasses();
    return null;
  }

  Future<List<CategoryModel>> categoriesForUser(int userId) =>
      _repo.getCategories(userId);

  Future<void> _syncLearnerCategoriesToCloud() async {
    if (!CloudScope.syncMonitoring) return;
    if (_user == null || !_user!.isLearner || !_notificationSync.isCloudAvailable) {
      return;
    }
    final uid = await _learnerFirebaseUidForSync();
    if (uid == null || uid.isEmpty) return;
    final categories = await _repo.getCategories(_user!.id);
    if (categories.isEmpty) return;
    await _notificationSync.syncLearnerCategories(
      learnerFirebaseUid: uid,
      categories: categories
          .map(
            (c) => RemoteLearnerCategory(
              key: c.key,
              name: c.name,
              iconKey: c.iconKey,
            ),
          )
          .toList(),
    );
  }

  Future<void> _syncLearnerCustomPhrasesToCloud() async {
    if (!CloudScope.syncMonitoring) return;
    if (_user == null || !_user!.isLearner || !_notificationSync.isCloudAvailable) {
      return;
    }
    final uid = await _learnerFirebaseUidForSync();
    if (uid == null || uid.isEmpty) return;
    final phrases = await _repo.getCustomPhrasesForCloudSync(_user!.id);
    await _notificationSync.syncLearnerCustomPhrases(
      learnerFirebaseUid: uid,
      phrases: phrases,
    );
  }

  Future<void> _pullLearnerCustomPhrasesFromCloud(int learnerUserId) async {
    if (!CloudScope.syncMonitoring) return;
    if (await NetworkStatus.isOffline()) return;
    await FirebaseService.instance.initialize();
    await _notificationSync.initialize();
    if (!_notificationSync.isCloudAvailable) return;
    if (_user != null && (_user!.isParent || _user!.isTeacher)) {
      if (!await _ensureCloudAuthSession()) return;
    }
    final learnerFirebaseUid = await _resolveLearnerFirebaseUid(learnerUserId);
    if (learnerFirebaseUid == null || learnerFirebaseUid.isEmpty) return;
    try {
      final phrases = await _notificationSync
          .getLearnerCustomPhrasesFromCloud(learnerFirebaseUid)
          .timeout(const Duration(seconds: 15));
      await _repo.mergeRemoteLearnerCustomPhrases(
        learnerUserId: learnerUserId,
        phrases: phrases,
      );
    } catch (e, st) {
      debugPrint('Pull learner custom phrases failed: $e\n$st');
    }
  }

  /// All learner categories (default + custom), synced from cloud when needed.
  Future<List<CategoryModel>> getCategoriesForMonitoring(
    int learnerUserId,
  ) async {
    var categories = await _repo.getCategories(learnerUserId);
    if (categories.isEmpty) {
      await _repo.seedLearnerData(learnerUserId);
      categories = await _repo.getCategories(learnerUserId);
    }
    if (!CloudScope.syncMonitoring) return categories;
    if (await NetworkStatus.isOffline()) return categories;
    final uid = await _resolveLearnerFirebaseUid(learnerUserId);
    if (uid != null && uid.isNotEmpty && _notificationSync.isCloudAvailable) {
      try {
        final remote =
            await _notificationSync.getLearnerCategoriesFromCloud(uid);
        if (remote.isNotEmpty) {
          await _repo.mergeRemoteLearnerCategories(
            learnerUserId: learnerUserId,
            remoteCategories: remote,
          );
          categories = await _repo.getCategories(learnerUserId);
        }
      } catch (e, st) {
        debugPrint('Pull monitoring categories failed: $e\n$st');
      }
    }
    return categories;
  }

  Future<List<PhraseUsageStat>> getSelectedChildPhraseStats({
    required ChildUsagePeriod period,
    DateTime? month,
  }) async {
    final child = selectedChild;
    if (child == null) return [];
    return getChildPhraseStats(
      learnerUserId: child.learnerId,
      period: period,
      month: month,
    );
  }

  Future<String?> _linkLearnerFirebaseUid({
    required int learnerUserId,
    required String learnerFirebaseUid,
  }) async {
    final uid = learnerFirebaseUid.trim();
    if (uid.isEmpty) return null;
    await _repo.linkFirebaseUid(learnerUserId, uid);
    return uid;
  }

  Future<String?> _resolveLearnerFirebaseUid(int learnerUserId) async {
    final fromUser = await _repo.getFirebaseUidForUser(learnerUserId);
    if (fromUser != null && fromUser.isNotEmpty) return fromUser;

    if (!CloudScope.syncMonitoring) return null;
    await FirebaseService.instance.initialize();
    await _notificationSync.initialize();
    if (!_notificationSync.isCloudAvailable || _user == null) return null;
    if (_user!.isParent || _user!.isTeacher) {
      if (!await _ensureCloudAuthSession()) return null;
    }

    try {
      final learner = await _repo.findUserById(learnerUserId);
      final learnerName = learner?.fullName.trim().toLowerCase();

      if (_user!.isParent) {
        final parentFirebaseUid = await _resolveParentFirebaseUid();
        if (parentFirebaseUid != null && parentFirebaseUid.isNotEmpty) {
          final links = await _notificationSync
              .getParentChildLinksFromCloud(parentFirebaseUid)
              .timeout(const Duration(seconds: 8));
          for (final link in links) {
            final uid = link.learnerFirebaseUid.trim();
            if (uid.isEmpty) continue;
            if (link.learnerUserId == learnerUserId) {
              return _linkLearnerFirebaseUid(
                learnerUserId: learnerUserId,
                learnerFirebaseUid: uid,
              );
            }
            if (learnerName != null &&
                learnerName.isNotEmpty &&
                link.learnerName.trim().toLowerCase() == learnerName) {
              return _linkLearnerFirebaseUid(
                learnerUserId: learnerUserId,
                learnerFirebaseUid: uid,
              );
            }
            final byUid = await _repo.findUserByFirebaseUid(uid);
            if (byUid?.id == learnerUserId) {
              return _linkLearnerFirebaseUid(
                learnerUserId: learnerUserId,
                learnerFirebaseUid: uid,
              );
            }
          }
        }
      }

      if (_user!.isTeacher) {
        final teacherFirebaseUid = await _resolveAccountFirebaseUid();
        if (teacherFirebaseUid != null && teacherFirebaseUid.isNotEmpty) {
          await _syncTeacherClassesFromCloud();
          final enrollments = await _notificationSync
              .getClassEnrollmentsFromCloud(teacherFirebaseUid)
              .timeout(const Duration(seconds: 10));
          for (final enrollment in enrollments) {
            final uid = enrollment.learnerFirebaseUid.trim();
            if (uid.isEmpty) continue;
            if (enrollment.learnerUserId == learnerUserId) {
              return _linkLearnerFirebaseUid(
                learnerUserId: learnerUserId,
                learnerFirebaseUid: uid,
              );
            }
            if (learnerName != null &&
                learnerName.isNotEmpty &&
                enrollment.learnerName.trim().toLowerCase() == learnerName) {
              return _linkLearnerFirebaseUid(
                learnerUserId: learnerUserId,
                learnerFirebaseUid: uid,
              );
            }
            final byUid = await _repo.findUserByFirebaseUid(uid);
            if (byUid?.id == learnerUserId) {
              return _linkLearnerFirebaseUid(
                learnerUserId: learnerUserId,
                learnerFirebaseUid: uid,
              );
            }
          }
        }
      }

      final profileCode = await _repo.ensureLearnerProfileCode(learnerUserId);
      if (profileCode.trim().isNotEmpty) {
        final remote = await _notificationSync
            .findLearnerProfileByCodeFromCloud(profileCode)
            .timeout(const Duration(seconds: 8));
        final uid = remote?.learnerFirebaseUid.trim() ?? '';
        if (uid.isNotEmpty) {
          await _repo.linkFirebaseUid(learnerUserId, uid);
          return uid;
        }
      }
    } catch (e, st) {
      debugPrint('Resolve learner firebase uid failed: $e\n$st');
    }

    return null;
  }

  Future<DateTime> getLearnerMonitoringSince(int learnerUserId) async {
    return _repo.getEarliestLearnerTrackingDate(learnerUserId);
  }

  /// Ensures cloud links are fresh before parent/teacher monitoring reloads.
  Future<void> refreshChildMonitoringData(int learnerUserId) async {
    if (_user == null) return;
    await FirebaseService.instance.initialize();
    await _notificationSync.initialize();
    if (_user!.isParent || _user!.isTeacher) {
      if (!await _ensureCloudAuthSession()) return;
    }
    final online = !await NetworkStatus.isOffline();
    if (online) {
      if (_user!.isTeacher) {
        await _syncTeacherClassesFromCloud();
      } else if (_user!.isParent) {
        await _loadLinkedChildren(syncCloudInBackground: false);
      }
    }
    await _resolveLearnerFirebaseUid(learnerUserId);
    if (online) {
      await _syncLearnerEnrollmentsFromCloudForUser(learnerUserId);
      await getCategoriesForMonitoring(learnerUserId);
      await _pullLearnerCustomPhrasesFromCloud(learnerUserId);
      await _pullLearnerMonitoringCacheFromCloud(learnerUserId);
    }
  }

  Future<List<PhraseUsageStat>> getChildPhraseStats({
    required int learnerUserId,
    required ChildUsagePeriod period,
    DateTime? month,
    bool syncCloud = true,
  }) async {
    if (syncCloud &&
        CloudScope.syncMonitoring &&
        !await NetworkStatus.isOffline()) {
      await _pullLearnerMonitoringCacheFromCloud(learnerUserId);
    }
    final range = _dateRangeForPeriod(period, month: month);
    return _repo.getPhraseUsageStats(
      learnerUserId: learnerUserId,
      rangeStart: range.$1,
      rangeEnd: range.$2,
    );
  }

  Future<VocabularyGrowthSummary> getChildVocabularyGrowth({
    required int learnerUserId,
    required ChildUsagePeriod period,
    DateTime? month,
    DateTime? linkedAt,
  }) async {
    final linked = linkedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final firstUses = await _repo.getCustomPhraseAdditions(
      learnerUserId: learnerUserId,
    );
    final range = _dateRangeForPeriod(period, month: month);
    final locale =
        _language == AppLanguage.filipino ? 'fil_PH' : 'en_US';
    final earliest = linked.isAfter(range.$1) ? linked : range.$1;

    final periodFirstUses = firstUses
        .where(
          (entry) =>
              !entry.firstUsedAt.isBefore(range.$1) &&
              entry.firstUsedAt.isBefore(range.$2),
        )
        .toList();

    return VocabularyGrowthCalculator.summarize(
      firstUses: periodFirstUses,
      now: DateTime.now(),
      rangeStart: earliest,
      localeName: locale,
    );
  }

  Future<List<ChildLessonProgressEntry>> getChildLessonProgress({
    required int learnerUserId,
    required ChildUsagePeriod period,
    DateTime? month,
  }) async {
    final range = _dateRangeForPeriod(period, month: month);
    return _repo.getChildLessonProgress(
      learnerUserId: learnerUserId,
      rangeStart: range.$1,
      rangeEnd: range.$2,
    );
  }

  Future<void> _syncLearnerEnrollmentsFromCloudForUser(int learnerUserId) async {
    if (!CloudScope.syncMonitoring) return;
    if (!_notificationSync.isCloudAvailable) return;
    final uid = await _resolveLearnerFirebaseUid(learnerUserId);
    if (uid == null || uid.isEmpty) return;
    try {
      final remoteEnrollments = await _notificationSync
          .getClassEnrollmentsForLearnerFromCloud(uid)
          .timeout(const Duration(seconds: 12));
      await _applyRemoteEnrollmentsForLearner(
        learnerUserId: learnerUserId,
        remoteEnrollments: remoteEnrollments,
      );
    } catch (e, st) {
      debugPrint('Sync learner enrollments for monitoring failed: $e\n$st');
    }
  }

  Future<List<EnrolledClassModel>> getEnrolledClassesForMonitoring(
    int learnerUserId, {
    bool syncCloud = false,
  }) async {
    if (syncCloud) {
      await _syncLearnerEnrollmentsFromCloudForUser(learnerUserId);
    }
    return _repo.getEnrolledClasses(learnerUserId);
  }

  Future<List<ClassLesson>> getClassLessonsForMonitoring({
    required int classId,
    required String classCode,
    bool syncCloud = false,
  }) async {
    if (syncCloud) {
      await _syncClassLessonsFromCloud(
        classId: classId,
        classCode: classCode,
      );
    }
    return _repo.getClassLessonsByClassId(classId);
  }

  Future<ChildLessonProgressEntry> getLessonProgressForMonitoring({
    required int learnerUserId,
    required String className,
    required String lessonTitle,
    required ChildUsagePeriod period,
    DateTime? month,
  }) async {
    final range = _dateRangeForPeriod(period, month: month);
    return _repo.getLessonProgressForLesson(
      learnerUserId: learnerUserId,
      className: className,
      lessonTitle: lessonTitle,
      rangeStart: range.$1,
      rangeEnd: range.$2,
    );
  }

  Future<ChildSessionSummary> getChildSessionSummary({
    required int learnerUserId,
    required ChildUsagePeriod period,
    DateTime? month,
    bool syncCloud = true,
  }) async {
    if (syncCloud &&
        CloudScope.syncMonitoring &&
        !await NetworkStatus.isOffline()) {
      await _pullLearnerMonitoringCacheFromCloud(learnerUserId);
    }
    final range = _dateRangeForPeriod(period, month: month);
    final allEvents = await _repo.getHistoryTimestamps(
      learnerUserId: learnerUserId,
      rangeStart: range.$1,
      rangeEnd: range.$2,
      personalOnly: true,
    );
    final locale =
        _language == AppLanguage.filipino ? 'fil_PH' : 'en_US';
    return SessionUsageCalculator.summarize(
      events: allEvents,
      period: period,
      rangeStart: range.$1,
      rangeEnd: range.$2,
      localeName: locale,
      now: DateTime.now(),
    );
  }

  (DateTime, DateTime) _dateRangeForPeriod(
    ChildUsagePeriod period, {
    DateTime? month,
  }) {
    final now = DateTime.now();
    switch (period) {
      case ChildUsagePeriod.today:
        final start = DateTime(now.year, now.month, now.day);
        return (start, start.add(const Duration(days: 1)));
      case ChildUsagePeriod.thisWeek:
        final weekday = now.weekday;
        final start = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: weekday - 1));
        return (start, start.add(const Duration(days: 7)));
      case ChildUsagePeriod.month:
        final m = month ?? DateTime(now.year, now.month);
        final start = DateTime(m.year, m.month);
        final end = DateTime(m.year, m.month + 1);
        return (start, end);
    }
  }

  String get profileCode =>
      (_user?.isLearner ?? false) ? _profileCode : '';

  Future<String?> updateProfileName(String fullName) async {
    if (_user == null) return AppStrings.notSignedIn(_language);
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return AppStrings.fillAllFields(_language);
    await _repo.updateUserFullName(_user!.id, trimmed);
    _user = _user!.copyWith(fullName: trimmed);
    if (CloudScope.syncMonitoring) {
      await FirebaseService.instance.initialize();
      await _notificationSync.initialize();
      await _syncUserProfileToCloud();
      if (_user!.isLearner) {
        final learnerFirebaseUid =
            _user!.firebaseUid ?? FirebaseService.instance.currentUid;
        if (learnerFirebaseUid != null && learnerFirebaseUid.isNotEmpty) {
          final profileCode = _profileCode.isNotEmpty
              ? _profileCode
              : await _repo.ensureLearnerProfileCode(_user!.id);
          await _notificationSync.updateLearnerReferencesOnCloud(
            learnerFirebaseUid: learnerFirebaseUid,
            learnerName: trimmed,
            learnerProfileCode: profileCode,
          );
          await _resyncLearnerEnrollmentsToCloud();
        }
      }
    }
    notifyListeners();
    return null;
  }

  Future<String?> updateEmergencyContacts(List<String> contacts) async {
    if (_user == null) return AppStrings.notSignedIn(_language);
    final cleaned = AppRepository.normalizeEmergencyContacts(contacts);
    await _repo.updateEmergencyContacts(_user!.id, cleaned);
    _emergencyContacts = cleaned;
    if (_user!.isLearner && CloudScope.syncMonitoring) {
      final learnerFirebaseUid =
          _user!.firebaseUid ?? FirebaseService.instance.currentUid;
      if (learnerFirebaseUid != null && learnerFirebaseUid.isNotEmpty) {
        await _notificationSync.syncLearnerEmergencyContacts(
          learnerUserId: _user!.id,
          learnerName: _user!.fullName,
          learnerFirebaseUid: learnerFirebaseUid,
          contacts: cleaned,
        );
      }
    }
    notifyListeners();
    return null;
  }

  Future<String?> changePassword(String currentPassword, String newPassword) async {
    if (_user == null) return AppStrings.notSignedIn(_language);
    if (currentPassword.isEmpty || newPassword.isEmpty) {
      return AppStrings.fillAllFields(_language);
    }
    if (!AuthValidation.isStrongPassword(newPassword)) {
      return AppStrings.passwordTooShort(_language);
    }
    final ok = await _repo.updateUserPassword(_user!.id, currentPassword, newPassword);
    if (!ok) return AppStrings.wrongCurrentPassword(_language);
    _user = _user!.copyWith(passwordHash: AppRepository.hashPassword(newPassword));
    notifyListeners();
    return null;
  }

  Future<bool> speakText(
    String text, {
    bool record = false,
    String? categoryKey,
    String? className,
    String? lessonTitle,
  }) async {
    final catKey = categoryKey ?? _selectedCategoryKey;
    final spoken = text.trim();
    if (spoken.isEmpty) {
      _currentSpeakGeneration = null;
      _resetSpeechTracking();
      notifyListeners();
      return false;
    }

    if (_speechPaused && spoken == _pausedSpeechText.trim()) {
      return _resumePausedSpeech(
        record: record,
        categoryKey: catKey,
        className: className,
        lessonTitle: lessonTitle,
      );
    }

    final gen = ++_ttsGeneration;
    _currentSpeakGeneration = null;
    _speechPaused = false;
    _pausedSpeechText = '';
    _resumeWordIndex = 0;
    _speechResumeCharOffset = 0;
    _speechHighlightOffset = 0;
    await tts.stop();
    _currentSpeakGeneration = gen;

    _speakingText = spoken;
    _isSpeaking = true;
    _spokenWordStart = -1;
    _spokenWordEnd = -1;
    _startReadAlongFallback(fromWordIndex: 0);
    notifyListeners();

    final ok = await tts.speak(spoken, rate: ttsSpeed, lang: _language);
    final cancelled = gen != _ttsGeneration;
    if (cancelled || !ok) {
      if (!cancelled) {
        _currentSpeakGeneration = null;
        _resetSpeechTracking();
        notifyListeners();
      }
      return false;
    }

    _currentSpeakGeneration = null;
    _resetSpeechTracking();
    notifyListeners();

    if (record) {
      await recordHistory(
        text,
        categoryKey: catKey,
        className: className,
        lessonTitle: lessonTitle,
      );
    }
    return true;
  }

  Future<bool> _resumePausedSpeech({
    required bool record,
    required String categoryKey,
    String? className,
    String? lessonTitle,
  }) async {
    final fullText = _pausedSpeechText.trim();
    if (fullText.isEmpty) {
      _resetSpeechTracking();
      notifyListeners();
      return false;
    }

    final offset = _speechResumeCharOffset.clamp(0, fullText.length);
    final remaining = fullText.substring(offset).trimLeft();
    if (remaining.isEmpty) {
      _resetSpeechTracking();
      notifyListeners();
      return true;
    }

    final gen = ++_ttsGeneration;
    _currentSpeakGeneration = gen;
    _speechPaused = false;
    _speechHighlightOffset = offset;

    _speakingText = fullText;
    _isSpeaking = true;
    _startReadAlongFallback(fromWordIndex: _resumeWordIndex);
    notifyListeners();

    final ok = await tts.speak(remaining, rate: ttsSpeed, lang: _language);
    final cancelled = gen != _ttsGeneration;
    if (cancelled || !ok) {
      if (!cancelled) {
        _currentSpeakGeneration = null;
        _resetSpeechTracking();
        notifyListeners();
      }
      return false;
    }

    _currentSpeakGeneration = null;
    _resetSpeechTracking();
    notifyListeners();

    if (record) {
      await recordHistory(
        fullText,
        categoryKey: categoryKey,
        className: className,
        lessonTitle: lessonTitle,
      );
    }
    return true;
  }

  Future<void> pauseSpeech() async {
    if (!_isSpeaking || _speechPaused) return;

    _pausedSpeechText = _speakingText;
    if (_spokenWordStart >= 0) {
      _resumeWordIndex = _wordIndexAtOffset(_speakingText, _spokenWordStart);
      final ranges = _wordRanges(_speakingText);
      if (_resumeWordIndex < ranges.length) {
        _speechResumeCharOffset = ranges[_resumeWordIndex].$1;
      } else {
        _speechResumeCharOffset = _spokenWordStart;
      }
    } else {
      _resumeWordIndex = _readAlongWordIndex;
      final ranges = _wordRanges(_speakingText);
      if (_resumeWordIndex < ranges.length) {
        _speechResumeCharOffset = ranges[_resumeWordIndex].$1;
      } else {
        _speechResumeCharOffset = 0;
      }
    }

    final ranges = _wordRanges(_speakingText);
    if (_resumeWordIndex < ranges.length) {
      final (start, end) = ranges[_resumeWordIndex];
      _spokenWordStart = start;
      _spokenWordEnd = end;
    }

    _ttsGeneration++;
    _currentSpeakGeneration = null;
    await tts.stop();

    _isSpeaking = false;
    _speechPaused = true;
    _stopReadAlongFallback();
    notifyListeners();
  }

  Future<void> stopSpeech() async {
    _ttsGeneration++;
    _currentSpeakGeneration = null;
    await tts.stop();
    _resetSpeechTracking();
    notifyListeners();
  }
}

