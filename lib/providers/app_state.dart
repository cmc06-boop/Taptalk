import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../core/l10n/app_strings.dart';
import '../core/utils/phrase_image_storage.dart';
import '../core/l10n/content_localization.dart';
import '../data/models/category_model.dart';
import '../core/constants/app_spacing.dart';
export '../core/constants/child_usage_period.dart';
import '../core/constants/child_usage_period.dart';
import '../core/utils/session_usage_calculator.dart';
import '../core/utils/vocabulary_growth_calculator.dart';
import '../data/models/child_session_summary.dart';
import '../data/models/vocabulary_growth_summary.dart';
import '../core/constants/tts_speed_options.dart';
import '../core/theme/theme_tokens.dart';
import '../data/database/database_helper.dart';
import '../data/models/favorite_model.dart';
import '../data/models/history_model.dart';
import '../data/models/enrolled_class_model.dart';
import '../data/models/linked_child_model.dart';
import '../data/models/parent_notification.dart';
import '../data/models/phrase_model.dart';
import '../data/models/phrase_usage_stat.dart';
import '../data/models/class_lesson.dart';
import '../data/models/lesson_phrase.dart';
import '../data/models/teacher_class_student.dart';
import '../data/models/user_model.dart';
import '../data/repositories/app_repository.dart';
import '../services/tts_service.dart';

enum AppRoute {
  welcome,
  login,
  register,
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
}

class AppState extends ChangeNotifier {
  AppState() {
    _bindTtsCallbacks();
    _init();
  }

  final AppRepository _repo = AppRepository(DatabaseHelper.instance);
  final TtsService tts = TtsService();

  bool _loading = true;
  UserModel? _user;
  AppRoute _route = AppRoute.welcome;
  TapTalkThemeToken _theme = TapTalkThemes.appDefault;
  AppLanguage _language = AppLanguage.english;
  double _ttsSpeed = 1.0;
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
    final tick = Duration(milliseconds: (360 / _ttsSpeed).clamp(180, 700).round());
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
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      _language = prefs.getString('lang') == 'fil'
          ? AppLanguage.filipino
          : AppLanguage.english;
      _ttsSpeed = TtsSpeedOptions.snap(
        prefs.getDouble('tts_speed') ?? TtsSpeedOptions.defaultSpeed,
      );
      await tts.init();

      if (userId != null) {
        _user = await _repo.findUserById(userId);
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
            await _loadTeacherClasses();
            _route = AppRoute.teacherDashboard;
          } else {
            _route = AppRoute.login;
          }
        }
      }
    } catch (e, st) {
      debugPrint('TapTalk init failed: $e\n$st');
      _route = AppRoute.welcome;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  String _categoryOnboardingKey(int userId) => 'category_onboarding_$userId';

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

  Future<void> _loadLearnerData() async {
    if (_user == null) return;
    final settings = await _repo.getUserSettings(_user!.id);
    _ttsSpeed = TtsSpeedOptions.snap(
      (settings['tts_speed'] as num?)?.toDouble() ?? _ttsSpeed,
    );
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('lang')) {
      _language = prefs.getString('lang') == 'fil'
          ? AppLanguage.filipino
          : AppLanguage.english;
    } else {
      _applyLanguageFromSettings(settings);
    }
    await _syncLanguagePref();
    if (_user != null) {
      await _repo.updateUserSettings(
        _user!.id,
        language: _language == AppLanguage.filipino ? 'Filipino' : 'English',
      );
    }
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
      await _loadEnrolledClasses();
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', AppStrings.langCode(_language));
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('tts_speed', _ttsSpeed);
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
    final ok = await _repo.verifyLogin(email, password);
    if (!ok) return AppStrings.invalidEmailPassword(_language);
    _user = await _repo.findUserByEmail(email);
    if (_user == null) return AppStrings.loginFailed(_language);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', _user!.id);
    if (_user!.needsTheme) {
      _theme = TapTalkThemes.appDefault;
    } else {
      _theme = TapTalkThemes.byKey(_user!.themeKey);
    }
    if (_user!.isLearner) {
      await _loadLearnerData();
      if (_user!.needsTheme) {
        _route = AppRoute.chooseTheme;
      } else {
        final categoryDone = await _isCategoryOnboardingDone(_user!.id);
        _route = categoryDone ? AppRoute.home : AppRoute.chooseCategory;
      }
    } else if (_user!.isParent) {
      await _loadLearnerData();
      await _ensureStarterData();
      await _loadLinkedChildren();
      _route = AppRoute.home;
    } else if (_user!.isTeacher) {
      _theme = TapTalkThemes.byKey(_user!.themeKey ?? 'mint_green');
      await _loadLearnerData();
      await _ensureStarterData();
      await _loadTeacherClasses();
      _route = AppRoute.teacherDashboard;
    } else {
      _route = AppRoute.login;
      return AppStrings.parentTeacherComingSoon(_language);
    }
    notifyListeners();
    return null;
  }

  Future<String?> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    final existing = await _repo.findUserByEmail(email);
    if (existing != null) return AppStrings.emailInUse(_language);
    _user = await _repo.registerUser(
      fullName: fullName,
      email: email,
      password: password,
      role: role,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', _user!.id);
    await _repo.updateUserSettings(
      _user!.id,
      language: _language == AppLanguage.filipino ? 'Filipino' : 'English',
    );
    if (role == 'learner') {
      _theme = TapTalkThemes.appDefault;
      await _setCategoryOnboardingDone(_user!.id, false);
      await _loadLearnerData();
      _route = AppRoute.chooseTheme;
    } else if (role == 'parent') {
      _theme = TapTalkThemes.byKey(_user!.themeKey ?? 'mint_green');
      await _loadLearnerData();
      await _ensureStarterData();
      await _loadLinkedChildren();
      _route = AppRoute.home;
    } else if (role == 'teacher') {
      _theme = TapTalkThemes.byKey(_user!.themeKey ?? 'mint_green');
      await _loadLearnerData();
      await _ensureStarterData();
      await _loadTeacherClasses();
      _route = AppRoute.teacherDashboard;
    } else {
      _route = AppRoute.login;
    }
    notifyListeners();
    return null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
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
    _route = AppRoute.login;
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
  }) async {
    if (_user == null || text.trim().isEmpty) return;
    final canonical = ContentLocalization.canonicalPhrase(text);
    await _repo.addHistory(
      userId: _user!.id,
      text: canonical,
      categoryKey: categoryKey ?? _selectedCategoryKey,
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

  Future<void> _loadLinkedChildren() async {
    if (_user == null || !_user!.isParent) {
      _linkedChildren = [];
      _selectedChildId = null;
      return;
    }
    _linkedChildren = await _repo.getLinkedChildren(_user!.id);
    if (_linkedChildren.isEmpty) {
      _selectedChildId = null;
    } else if (_selectedChildId == null ||
        !_linkedChildren.any((c) => c.learnerId == _selectedChildId)) {
      _selectedChildId = _linkedChildren.first.learnerId;
    }
    await _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (_user == null || !_user!.isParent) {
      _notifications = [];
      return;
    }
    final childName = _linkedChildren.isNotEmpty
        ? _linkedChildren.first.fullName
        : (_language == AppLanguage.filipino ? 'ang iyong anak' : 'your child');
    await _repo.seedParentNotificationsIfEmpty(
      parentUserId: _user!.id,
      childName: childName,
      learnerUserId:
          _linkedChildren.isNotEmpty ? _linkedChildren.first.learnerId : null,
      filipino: _language == AppLanguage.filipino,
    );
    _notifications = await _repo.getParentNotifications(_user!.id);
  }

  Future<void> markNotificationRead(int notificationId) async {
    await _repo.markNotificationRead(notificationId);
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index >= 0) {
      _notifications[index] =
          _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  Future<void> markAllNotificationsRead() async {
    if (_user == null || !_user!.isParent) return;
    await _repo.markAllNotificationsRead(_user!.id);
    _notifications = [
      for (final n in _notifications) n.copyWith(isRead: true),
    ];
    notifyListeners();
  }

  Future<void> refreshNotifications() async {
    await _loadNotifications();
    notifyListeners();
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
    final learner = await _repo.findLearnerByProfileCode(normalized);
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
    await _loadLinkedChildren();
    _selectedChildId = learner.id;
    notifyListeners();
    return null;
  }

  Future<String?> unlinkChild(int learnerId) async {
    if (_user == null || !_user!.isParent) {
      return AppStrings.notSignedIn(_language);
    }
    await _repo.unlinkParentChild(_user!.id, learnerId);
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
    if (result == 'empty') {
      return AppStrings.enterClassName(_language);
    }
    await _loadTeacherClasses();
    notifyListeners();
    return null;
  }

  Future<String?> deleteTeacherClass(int classId) async {
    if (_user == null || !_user!.isTeacher) {
      return AppStrings.notSignedIn(_language);
    }
    final ok = await _repo.deleteTeacherClass(
      teacherUserId: _user!.id,
      classId: classId,
    );
    if (!ok) return AppStrings.classNotFound(_language);
    await _loadTeacherClasses();
    notifyListeners();
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

  Future<ClassLesson?> createClassLesson(int classId, String title) async {
    if (_user == null || !_user!.isTeacher) return null;
    return _repo.createClassLesson(
      teacherUserId: _user!.id,
      classId: classId,
      title: title,
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

  Future<List<TeacherClassStudent>> getTeacherClassStudents() async {
    if (_user == null || !_user!.isTeacher) return [];
    return _repo.getTeacherClassStudents(_user!.id);
  }

  Future<void> _loadEnrolledClasses() async {
    if (_user == null || !_user!.isLearner) {
      _enrolledClasses = [];
      return;
    }
    _enrolledClasses = await _repo.getEnrolledClasses(_user!.id);
  }

  Future<String?> enrollByClassCode(String code) async {
    if (_user == null || !_user!.isLearner) {
      return AppStrings.notSignedIn(_language);
    }
    final normalized = AppRepository.normalizeClassCode(code);
    if (!AppRepository.isValidClassCodeFormat(normalized)) {
      return AppStrings.invalidClassCode(_language);
    }
    final classRow = await _repo.findClassByCode(normalized);
    if (classRow == null) {
      return AppStrings.classNotFound(_language);
    }
    final classId = classRow['id'] as int;
    if (await _repo.isLearnerEnrolled(_user!.id, classId)) {
      return AppStrings.classAlreadyEnrolled(_language);
    }
    await _repo.enrollLearnerInClass(_user!.id, classId);
    await _loadEnrolledClasses();
    return null;
  }

  /// Call after UI that triggered enroll has closed (avoids rebuild during dialog).
  void notifyEnrolledClassesChanged() => notifyListeners();

  Future<String?> leaveClass(int classId) async {
    if (_user == null || !_user!.isLearner) {
      return AppStrings.notSignedIn(_language);
    }
    await _repo.unenrollLearnerFromClass(_user!.id, classId);
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
    notifyListeners();
    return null;
  }

  Future<String?> changePassword(String currentPassword, String newPassword) async {
    if (_user == null) return AppStrings.notSignedIn(_language);
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
    final ok = await tts.speak(spoken, rate: _ttsSpeed, lang: _language);
    if (!ok) {
      _resetSpeechTracking();
      notifyListeners();
    }
    if (ok && record) {
      await recordHistory(canonical, categoryKey: catKey);
    }
    return ok;
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

