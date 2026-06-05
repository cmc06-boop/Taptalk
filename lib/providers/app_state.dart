import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../core/l10n/app_strings.dart';
import '../core/utils/auth_validation.dart';
import '../core/utils/phrase_image_storage.dart';
import '../core/l10n/content_localization.dart';
import '../data/models/category_model.dart';
import '../core/constants/app_spacing.dart';
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
  double _ttsSpeed = TtsSpeedOptions.defaultSpeed;
  String _selectedCategoryKey = 'feelings';
  bool _drawerOpen = false;
  bool _isSpeaking = false;
  String _speakingText = '';
  int _spokenWordStart = -1;
  int _spokenWordEnd = -1;
  Timer? _readAlongTimer;
  int _readAlongWordIndex = 0;
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

  bool get loading => _loading;
  UserModel? get user => _user;
  AppRoute get route => _route;
  TapTalkThemeToken get theme => _theme;
  AppLanguage get language => _language;
  double get ttsSpeed => _ttsSpeed;
  String get selectedCategoryKey => _selectedCategoryKey;
  bool get drawerOpen => _drawerOpen;
  bool get isSpeaking => _isSpeaking;
  String get speakingText => _speakingText;
  int get spokenWordStart => _spokenWordStart;
  int get spokenWordEnd => _spokenWordEnd;
  List<String> get emergencyContacts => List.unmodifiable(_emergencyContacts);
  List<CategoryModel> get categories => _categories;
  List<PhraseModel> get phrases => _phrases;
  List<FavoriteModel> get favorites => _favorites;
  List<HistoryModel> get history => _history;
  List<LinkedChildModel> get linkedChildren => _linkedChildren;
  List<ParentNotification> get notifications =>
      List.unmodifiable(_notifications);
  int get unreadNotificationCount =>
      _notifications.where((n) => !n.isRead).length;
  bool get isCloudNotificationsAvailable => _notificationSync.isCloudAvailable;
  List<EnrolledClassModel> get enrolledClasses => _enrolledClasses;
  List<({int id, String name, String code})> get teacherClasses =>
      _teacherClasses;
  int? get selectedChildId => _selectedChildId;

  LinkedChildModel? get selectedChild {
    if (_selectedChildId == null) return null;
    for (final c in _linkedChildren) {
      if (c.learnerId == _selectedChildId) return c;
    }
    return _linkedChildren.isNotEmpty ? _linkedChildren.first : null;
  }

  List<PhraseModel> get phrasesForCategory => _phrases
      .where((p) => p.categoryKey == _selectedCategoryKey && p.isActive)
      .toList();

  CategoryModel? get selectedCategory {
    for (final c in _categories) {
      if (c.key == _selectedCategoryKey) return c;
    }
    return null;
  }

  void _bindTtsCallbacks() {
    tts.onStart = () {
      _isSpeaking = true;
      _startReadAlongFallback();
      notifyListeners();
    };
    tts.onProgress = (text, start, end, word) {
      _stopReadAlongFallback();
      _speakingText = text;
      _spokenWordStart = start;
      _spokenWordEnd = end;
      notifyListeners();
    };
    tts.onComplete = () {
      _stopReadAlongFallback();
      _isSpeaking = false;
      _spokenWordStart = -1;
      _spokenWordEnd = -1;
      notifyListeners();
    };
    tts.onError = (_) {
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

  void _startReadAlongFallback() {
    _stopReadAlongFallback();
    final text = _speakingText.trim();
    if (text.isEmpty) return;
    final ranges = _wordRanges(_speakingText);
    if (ranges.isEmpty) return;
    _readAlongWordIndex = 0;
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
    _speakingText = '';
    _spokenWordStart = -1;
    _spokenWordEnd = -1;
  }

  Future<void> _init() async {
    try {
      await FirebaseService.instance.initialize();
      await _notificationSync.initialize();
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      await tts.init();

      if (userId != null) {
        _user = await _repo.findUserById(userId);
      }

      if (_user != null) {
        await _syncFirebaseSessionAfterRestore();
      }

      if (_user != null) {
          if (_user!.needsTheme) {
            _theme = TapTalkThemes.appDefault;
          } else {
            _theme = TapTalkThemes.byKey(_user!.themeKey);
          }
          await _loadLearnerData();
          if (_user!.needsTheme) {
            _route = AppRoute.chooseTheme;
          } else if (_user!.isLearner) {
            final categoryDone = await _isCategoryOnboardingDone(_user!.id);
            _route = categoryDone ? AppRoute.home : AppRoute.chooseCategory;
          } else if (_user!.isParent) {
            await _ensureStarterData();
            await _loadLinkedChildren();
            _route = AppRoute.home;
          } else if (_user!.isTeacher) {
            await _loadLearnerData();
            await _ensureStarterData();
            await refreshTeacherClasses();
            _route = AppRoute.teacherDashboard;
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
    }
  }

  String _categoryOnboardingKey(int userId) => 'category_onboarding_$userId';

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

  Future<void> _loadLearnerData({bool cloudSyncInBackground = false}) async {
    if (_user == null) return;
    final settings = await _repo.getUserSettings(_user!.id);
    _ttsSpeed = TtsSpeedOptions.snap(
      (settings['tts_speed'] as num?)?.toDouble() ?? TtsSpeedOptions.defaultSpeed,
    );
    _applyLanguageFromSettings(settings);
    await _syncLanguagePref();
    await _syncTtsSpeedPref();
    final contacts = settings['emergency_contacts'];
    if (contacts is List) {
      _emergencyContacts = contacts
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .take(2)
          .toList();
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

    _categories = await _repo.getCategories(_user!.id);
    _phrases = await _repo.getPhrases(_user!.id);
    _favorites = await _repo.getFavorites(_user!.id);
    _history = await _repo.getHistory(_user!.id);

    if (_categories.isNotEmpty &&
        !_categories.any((c) => c.key == _selectedCategoryKey)) {
      _selectedCategoryKey = _categories.first.key;
    }
  }

  Future<void> _syncLearnerCloudData() async {
    if (_user == null || !_user!.isLearner) return;
    try {
      final learnerFirebaseUid =
          _user!.firebaseUid ?? FirebaseService.instance.currentUid;
      if (learnerFirebaseUid != null && learnerFirebaseUid.isNotEmpty) {
        await _notificationSync.syncLearnerEmergencyContacts(
          learnerUserId: _user!.id,
          learnerName: _user!.fullName,
          learnerFirebaseUid: learnerFirebaseUid,
          contacts: _emergencyContacts,
          profileCode: _profileCode,
        );
      }
      await _resyncLearnerEnrollmentsToCloud();
      await _syncUserProfileToCloud();
    } catch (e, st) {
      debugPrint('Learner cloud sync failed: $e\n$st');
    }
  }

  Future<void> _syncUserProfileToCloud() async {
    if (_user == null || !_notificationSync.isCloudAvailable) return;
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
  }

  Future<void> _refreshLearnerCollections() async {
    if (_user == null) return;
    _categories = await _repo.getCategories(_user!.id);
    _phrases = await _repo.getPhrases(_user!.id);
    _favorites = await _repo.getFavorites(_user!.id);
    _history = await _repo.getHistory(_user!.id);
    if (_categories.isNotEmpty &&
        !_categories.any((c) => c.key == _selectedCategoryKey)) {
      _selectedCategoryKey = _categories.first.key;
    }
  }

  Future<void> _ensureStarterData() async {
    if (_user == null ||
        (!_user!.isParent && !_user!.isLearner && !_user!.isTeacher)) {
      return;
    }
    if (_categories.isNotEmpty) return;
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
    final norm = raw.trim().toLowerCase();
    if (norm.startsWith('fil') || norm == 'tagalog') {
      _language = AppLanguage.filipino;
    } else if (norm.startsWith('en')) {
      _language = AppLanguage.english;
    }
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
    _language = lang;
    await _syncLanguagePref();
    if (_user != null) {
      await _repo.updateUserSettings(
        _user!.id,
        language: lang == AppLanguage.filipino ? 'Filipino' : 'English',
      );
    }
    notifyListeners();
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

  String localizedPhrase(String text, String categoryKey) =>
      ContentLocalization.phrase(
        text,
        categoryKey,
        lang: _language,
      );

  String localizedPhraseText(PhraseModel phrase) =>
      localizedPhrase(phrase.text, phrase.categoryKey);

  String localizedContent(String text) =>
      ContentLocalization.freeText(text, _language);

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

    var user = await _repo.findUserByEmail(normalizedEmail);
    if (user == null) {
      // Account may exist only in Firebase (registered on another device).
      if (FirebaseService.instance.isAvailable) {
        final uid = await FirebaseService.instance.signIn(
          email: normalizedEmail,
          password: password,
        );
        if (uid != null) {
          final cloudProfile =
              await _notificationSync.getUserProfileFromCloud(uid);
          if (cloudProfile != null) {
            user = await _repo.provisionLocalUserFromCloud(
              email: normalizedEmail,
              password: password,
              firebaseUid: uid,
              profile: cloudProfile,
            );
          } else {
            return AppStrings.accountNotOnThisDevice(_language);
          }
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
        final hasLocalPassword =
            user.passwordHash != null && user.passwordHash!.isNotEmpty;
        if (!hasLocalPassword || user.isOnlineAccount) {
          return AppStrings.wrongPassword(_language);
        }
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
      if (user.isOnlineAccount) {
        return AppStrings.loginNeedsInternet(_language);
      }
      final ok = await _repo.verifyLogin(normalizedEmail, password);
      if (!ok) return AppStrings.wrongPassword(_language);
    }

    _user = user;
    if (_user == null) return AppStrings.loginFailed(_language);

    unawaited(_syncUserProfileToCloud());

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', _user!.id);
    if (_user!.needsTheme) {
      _theme = TapTalkThemes.appDefault;
    } else {
      _theme = TapTalkThemes.byKey(_user!.themeKey);
    }
    if (_user!.isLearner) {
      if (_user!.needsTheme) {
        _route = AppRoute.chooseTheme;
      } else {
        final categoryDone = await _isCategoryOnboardingDone(_user!.id);
        _route = categoryDone ? AppRoute.home : AppRoute.chooseCategory;
      }
    } else if (_user!.isParent) {
      _route = AppRoute.home;
    } else if (_user!.isTeacher) {
      _theme = TapTalkThemes.byKey(_user!.themeKey ?? 'mint_green');
      _route = AppRoute.teacherDashboard;
    } else {
      _route = AppRoute.login;
      return AppStrings.parentTeacherComingSoon(_language);
    }

    notifyListeners();

    try {
      if (_user!.isLearner) {
        await _loadLearnerData(cloudSyncInBackground: true);
      } else if (_user!.isParent) {
        await _loadLearnerData(cloudSyncInBackground: true);
        await _ensureStarterData();
        await _loadLinkedChildren(syncCloudInBackground: true);
      } else if (_user!.isTeacher) {
        await _loadLearnerData(cloudSyncInBackground: true);
        await _ensureStarterData();
        await refreshTeacherClasses();
      }
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
    await _repo.updateUserSettings(
      _user!.id,
      language: _language == AppLanguage.filipino ? 'Filipino' : 'English',
    );

    if (role == 'learner') {
      _theme = TapTalkThemes.appDefault;
      await _setCategoryOnboardingDone(_user!.id, false);
      _route = AppRoute.chooseTheme;
    } else if (role == 'parent') {
      _theme = TapTalkThemes.byKey(_user!.themeKey ?? 'mint_green');
      _route = AppRoute.home;
    } else if (role == 'teacher') {
      _theme = TapTalkThemes.byKey(_user!.themeKey ?? 'mint_green');
      _route = AppRoute.teacherDashboard;
    } else {
      _route = AppRoute.login;
    }

    notifyListeners();

    try {
      await _syncUserProfileToCloud();
      if (role == 'learner') {
        await _loadLearnerData(cloudSyncInBackground: true);
      } else if (role == 'parent') {
        await _loadLearnerData(cloudSyncInBackground: true);
        await _ensureStarterData();
        await _loadLinkedChildren(syncCloudInBackground: true);
      } else if (role == 'teacher') {
        await _loadLearnerData(cloudSyncInBackground: true);
        await _ensureStarterData();
        await refreshTeacherClasses();
      }
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
    await _notificationSync.stopParentSync();
    await FirebaseService.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    _language = AppLanguage.english;
    _ttsSpeed = TtsSpeedOptions.defaultSpeed;
    _user = null;
    _categories = [];
    _phrases = [];
    _favorites = [];
    _history = [];
    _linkedChildren = [];
    _notifications = [];
    _selectedChildId = null;
    _enrolledClasses = [];
    _teacherClasses = [];
    _theme = TapTalkThemes.appDefault;
    _emergencyContacts = [];
    _profileCode = '';
    _resetSpeechTracking();
    _route = AppRoute.welcome;
    _drawerOpen = false;
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
    }
    _route = AppRoute.home;
    notifyListeners();
  }

  Future<String?> addCategory(String name) async {
    if (_user == null) return AppStrings.notSignedIn(_language);
    try {
      final cat = await _repo.addCategory(_user!.id, name);
      _selectedCategoryKey = cat.key;
      await _refreshLearnerCollections();
      notifyListeners();
      return null;
    } catch (e) {
      return AppStrings.unableAddCategory(_language);
    }
  }

  Future<String?> addPhrase(String text, {String? imagePath}) async {
    if (_user == null || text.trim().isEmpty) return null;
    final savedImagePath = await persistPhraseImageIfNeeded(imagePath);
    final canonical = ContentLocalization.canonicalPhrase(text);
    await _repo.addPhrase(
      userId: _user!.id,
      text: canonical,
      categoryKey: _selectedCategoryKey,
      imagePath: savedImagePath,
    );
    await _refreshLearnerCollections();
    notifyListeners();
    return null;
  }

  Future<void> deletePhrase(PhraseModel phrase) async {
    if (_user == null) return;
    if (!phrase.isBuiltin) {
      await _repo.deletePhrase(_user!.id, phrase.id);
    }
    _phrases = await _repo.getPhrases(_user!.id);
    notifyListeners();
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
    if (_user == null) return;
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
    final canonical = ContentLocalization.canonicalPhrase(text);
    await _repo.addHistory(
      userId: _user!.id,
      text: canonical,
      categoryKey: categoryKey ?? _selectedCategoryKey,
      className: className,
      lessonTitle: lessonTitle,
    );
    _history = await _repo.getHistory(_user!.id);
    notifyListeners();
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
    if (syncCloudInBackground) {
      unawaited(_syncParentCloudAfterLogin());
    } else {
      await _syncLinkedChildrenToCloud();
      await _startParentNotificationSync();
    }
  }

  Future<void> _syncParentCloudAfterLogin() async {
    try {
      await _syncLinkedChildrenToCloud();
      await _startParentNotificationSync();
    } catch (e, st) {
      debugPrint('Parent cloud sync after login failed: $e\n$st');
    }
  }

  Future<void> _syncLinkedChildrenFromCloud() async {
    if (_user == null || !_user!.isParent) return;
    if (!_notificationSync.isCloudAvailable) return;

    final parentFirebaseUid =
        _user!.firebaseUid ?? FirebaseService.instance.currentUid;
    if (parentFirebaseUid == null || parentFirebaseUid.isEmpty) return;

    try {
      final links = await _notificationSync
          .getParentChildLinksFromCloud(parentFirebaseUid)
          .timeout(const Duration(seconds: 12));
      await _repo.mergeRemoteParentChildLinks(
        parentUserId: _user!.id,
        links: links,
      );
    } catch (e, st) {
      debugPrint('Pull parent-child links failed: $e\n$st');
    }
  }

  Future<void> _syncLinkedChildrenToCloud() async {
    if (_user == null || !_user!.isParent || _linkedChildren.isEmpty) return;
    final parentFirebaseUid =
        _user!.firebaseUid ?? FirebaseService.instance.currentUid;
    if (parentFirebaseUid == null || parentFirebaseUid.isEmpty) return;
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
    if (_user == null || !_user!.isParent) return;
    final firebaseUid =
        _user!.firebaseUid ?? FirebaseService.instance.currentUid;
    if (firebaseUid == null || firebaseUid.isEmpty) return;
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
    await _loadNotifications();
    notifyListeners();
  }

  Future<void> refreshTeacherClasses() async {
    if (_user == null || !_user!.isTeacher) {
      _teacherClasses = [];
      notifyListeners();
      return;
    }
    await _syncTeacherClassesFromCloud();
    await _loadTeacherClasses();
    notifyListeners();
  }

  Future<int> getTeacherStudentCount() async {
    if (_user == null || !_user!.isTeacher) return 0;
    final local = await _repo.getTeacherClassStudents(_user!.id);
    final localCount = local.length;
    if (!_notificationSync.isCloudAvailable) return localCount;

    final teacherFirebaseUid =
        _user!.firebaseUid ?? FirebaseService.instance.currentUid;
    if (teacherFirebaseUid == null || teacherFirebaseUid.isEmpty) {
      return localCount;
    }

    try {
      final enrollments = await _notificationSync
          .getClassEnrollmentsFromCloud(teacherFirebaseUid)
          .timeout(const Duration(seconds: 12));
      final cloudUnique = enrollments
          .map((e) => e.learnerFirebaseUid.trim())
          .where((uid) => uid.isNotEmpty)
          .toSet()
          .length;
      return localCount > cloudUnique ? localCount : cloudUnique;
    } catch (e, st) {
      debugPrint('Cloud teacher student count failed: $e\n$st');
      return localCount;
    }
  }

  Future<void> _syncTeacherClassesFromCloud() async {
    if (_user == null || !_user!.isTeacher) return;
    if (!_notificationSync.isCloudAvailable) return;

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
      );

      final enrollments = await _notificationSync
          .getClassEnrollmentsFromCloud(teacherFirebaseUid)
          .timeout(const Duration(seconds: 12));
      await _repo.mergeRemoteEnrollmentsForTeacher(
        teacherUserId: _user!.id,
        enrollments: enrollments,
      );
    } catch (e, st) {
      debugPrint('Teacher class cloud sync failed: $e\n$st');
    }
  }

  Future<void> _pushTeacherClassToCloud({
    required String classCode,
    required String className,
  }) async {
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
    var learner = await _repo.findLearnerByProfileCode(normalized);
    if (learner == null && _notificationSync.isCloudAvailable) {
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
    final learnerFirebaseUid = learner.firebaseUid;
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
      await _notificationSync.removeTeacherClass(classCode: classCode);
    }
    await refreshTeacherClasses();
    return null;
  }

  Future<int> studentCountForClass(int classId) async {
    return _repo.countStudentsInClass(classId);
  }

  Future<List<ClassLesson>> getClassLessons(int classId) async {
    if (_user == null || !_user!.isTeacher) return [];
    return _repo.getClassLessons(
      teacherUserId: _user!.id,
      classId: classId,
    );
  }

  Future<List<ClassLesson>> getEnrolledClassLessons(int classId) async {
    if (_user == null || !_user!.isLearner) return [];
    return _repo.getEnrolledClassLessons(
      learnerUserId: _user!.id,
      classId: classId,
    );
  }

  Future<List<LessonPhrase>> getEnrolledLessonPhrases(int lessonId) async {
    if (_user == null || !_user!.isLearner) return [];
    return _repo.getEnrolledLessonPhrases(
      learnerUserId: _user!.id,
      lessonId: lessonId,
    );
  }

  Future<ClassLesson?> createClassLesson(int classId, String title) async {
    if (_user == null || !_user!.isTeacher) return null;
    return _repo.createClassLesson(
      teacherUserId: _user!.id,
      classId: classId,
      title: ContentLocalization.canonicalPhrase(title.trim()),
    );
  }

  Future<bool> updateClassLesson(int lessonId, String title) async {
    if (_user == null || !_user!.isTeacher) return false;
    return _repo.updateClassLesson(
      teacherUserId: _user!.id,
      lessonId: lessonId,
      title: ContentLocalization.canonicalPhrase(title.trim()),
    );
  }

  Future<bool> deleteClassLesson(int lessonId) async {
    if (_user == null || !_user!.isTeacher) return false;
    return _repo.deleteClassLesson(
      teacherUserId: _user!.id,
      lessonId: lessonId,
    );
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
    final phrase = await _repo.addLessonPhrase(
      teacherUserId: _user!.id,
      lessonId: lessonId,
      text: ContentLocalization.canonicalPhrase(text),
      imagePath: saved,
    );
    return phrase == null ? AppStrings.unableAddPhrase(_language) : null;
  }

  Future<void> deleteLessonPhrase(int phraseId) async {
    if (_user == null || !_user!.isTeacher) return;
    await _repo.deleteLessonPhrase(
      teacherUserId: _user!.id,
      phraseId: phraseId,
    );
  }

  /// Local SQLite roster only — never blocks on Firestore (used by teacher UI).
  Future<List<TeacherClassStudent>> getTeacherClassStudentsForClass(
    int classId,
  ) async {
    if (_user == null || !_user!.isTeacher) return [];
    return _repo.getTeacherClassStudentsForClass(
      teacherUserId: _user!.id,
      classId: classId,
    );
  }

  Future<List<TeacherClassStudent>> getTeacherClassStudents() async {
    if (_user == null || !_user!.isTeacher) return [];
    final local = await _repo.getTeacherClassStudents(_user!.id);
    _scheduleTeacherEnrollmentCloudSync(local);
    if (local.isNotEmpty) return local;

    final teacherFirebaseUid =
        _user!.firebaseUid ?? FirebaseService.instance.currentUid;
    if (teacherFirebaseUid == null || teacherFirebaseUid.isEmpty) {
      return local;
    }
    try {
      return await _notificationSync
          .getTeacherClassStudentsFromCloud(teacherFirebaseUid)
          .timeout(const Duration(seconds: 12));
    } catch (e, st) {
      debugPrint('Cloud teacher roster fetch failed: $e\n$st');
      return local;
    }
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

    final localContacts =
        await _repo.getEmergencyContactsForLearner(learnerUserId);
    final learnerFirebaseUid =
        await _repo.getFirebaseUidForUser(learnerUserId);
    final contacts = await _notificationSync.resolveEmergencyContacts(
      learnerUserId: learnerUserId,
      localContacts: localContacts,
      learnerFirebaseUid: learnerFirebaseUid,
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
    await _resyncLearnerEnrollmentsToCloud();
  }

  Future<void> _resyncLearnerEnrollmentsToCloud() async {
    if (_user == null || !_user!.isLearner || !_notificationSync.isCloudAvailable) {
      return;
    }
    final learnerFirebaseUid =
        _user!.firebaseUid ?? FirebaseService.instance.currentUid;
    if (learnerFirebaseUid == null || learnerFirebaseUid.isEmpty) return;

    for (final enrolled in _enrolledClasses) {
      final teacherFirebaseUid =
          await _repo.getFirebaseUidForUser(enrolled.teacherId);
      if (teacherFirebaseUid == null || teacherFirebaseUid.isEmpty) continue;
      await _notificationSync.syncClassEnrollment(
        classId: enrolled.classId,
        classCode: enrolled.classCode,
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
    if (classRow == null) {
      if (!_notificationSync.isCloudAvailable) {
        return AppStrings.classNotFound(_language);
      }
      try {
        final remote = await _notificationSync
            .getTeacherClassByCodeFromCloud(normalized)
            .timeout(const Duration(seconds: 12));
        if (remote != null) {
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
    if (await _repo.isLearnerEnrolled(_user!.id, classId)) {
      return AppStrings.classAlreadyEnrolled(_language);
    }
    await _repo.enrollLearnerInClass(_user!.id, classId);
    final learnerFirebaseUid =
        _user!.firebaseUid ?? FirebaseService.instance.currentUid;
    final teacherUserId = classRow['teacher_user_id'] as int?;
    final teacherFirebaseUid = teacherUserId == null
        ? null
        : await _repo.getFirebaseUidForUser(teacherUserId);
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

  /// Reload enrolled classes from DB and refresh listeners.
  Future<void> refreshEnrolledClasses() async {
    await _loadEnrolledClasses();
    notifyListeners();
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

  Future<List<PhraseUsageStat>> getChildPhraseStats({
    required int learnerUserId,
    required ChildUsagePeriod period,
    DateTime? month,
  }) async {
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
    final firstUses = await _repo.getPhraseFirstUses(
      learnerUserId: learnerUserId,
    );
    final range = _dateRangeForPeriod(period, month: month);
    final locale =
        _language == AppLanguage.filipino ? 'fil_PH' : 'en_US';
    final linked = linkedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final earliest = linked.isAfter(range.$1) ? linked : range.$1;

    final periodStats = await getChildPhraseStats(
      learnerUserId: learnerUserId,
      period: period,
      month: month,
    );
    final usageByCategory = <String, int>{};
    final wordsByCategory = <String, int>{};
    final seenInPeriod = <String>{};
    for (final stat in periodStats) {
      usageByCategory.update(
        stat.categoryKey,
        (v) => v + stat.count,
        ifAbsent: () => stat.count,
      );
      final key = '${stat.categoryKey}|${stat.text}';
      if (seenInPeriod.add(key)) {
        wordsByCategory.update(
          stat.categoryKey,
          (v) => v + 1,
          ifAbsent: () => 1,
        );
      }
    }
    final periodSlices = periodStats.isEmpty
        ? null
        : VocabularyGrowthCalculator.categorySlicesFromUsage(
            usageByCategory: usageByCategory,
            wordsByCategory: wordsByCategory,
          );

    return VocabularyGrowthCalculator.summarize(
      firstUses: firstUses,
      now: DateTime.now(),
      rangeStart: earliest,
      localeName: locale,
      periodCategorySlices: periodSlices,
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

  Future<ChildSessionSummary> getChildSessionSummary({
    required int learnerUserId,
    required ChildUsagePeriod period,
    DateTime? month,
  }) async {
    final range = _dateRangeForPeriod(period, month: month);
    final events = await _repo.getHistoryTimestamps(
      learnerUserId: learnerUserId,
      rangeStart: range.$1,
      rangeEnd: range.$2,
    );
    final locale =
        _language == AppLanguage.filipino ? 'fil_PH' : 'en_US';
    return SessionUsageCalculator.summarize(
      events: events,
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
        return (start, now.add(const Duration(milliseconds: 1)));
      case ChildUsagePeriod.thisWeek:
        final weekday = now.weekday;
        final start = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: weekday - 1));
        return (start, now.add(const Duration(milliseconds: 1)));
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
    notifyListeners();
    return null;
  }

  Future<String?> updateEmergencyContacts(List<String> contacts) async {
    if (_user == null) return AppStrings.notSignedIn(_language);
    final cleaned = contacts
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .take(2)
        .toList();
    await _repo.updateEmergencyContacts(_user!.id, cleaned);
    _emergencyContacts = cleaned;
    if (_user!.isLearner) {
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
    final canonical = ContentLocalization.canonicalPhrase(text);
    final spoken = ContentLocalization.phrase(
      canonical,
      catKey,
      lang: _language,
    );
    _speakingText = spoken;
    _isSpeaking = true;
    _spokenWordStart = -1;
    _spokenWordEnd = -1;
    _startReadAlongFallback();
    notifyListeners();
    final ok = await tts.speak(spoken, rate: ttsSpeed, lang: _language);
    if (!ok) {
      _resetSpeechTracking();
      notifyListeners();
    }
    if (record) {
      await recordHistory(
        canonical,
        categoryKey: catKey,
        className: className,
        lessonTitle: lessonTitle,
      );
    }
    return ok;
  }

  Future<void> recordLessonOpen({
    required String className,
    required String lessonTitle,
  }) async {
    await recordHistory(
      lessonTitle,
      categoryKey: 'lesson',
      className: className,
      lessonTitle: lessonTitle,
    );
  }

  Future<void> pauseSpeech() async {
    await tts.pause();
    _stopReadAlongFallback();
    _isSpeaking = false;
    _spokenWordStart = -1;
    _spokenWordEnd = -1;
    notifyListeners();
  }

  Future<void> stopSpeech() async {
    await tts.stop();
    _resetSpeechTracking();
    notifyListeners();
  }
}

