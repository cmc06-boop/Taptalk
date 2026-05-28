import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../core/l10n/app_strings.dart';
import '../core/utils/phrase_image_storage.dart';
import '../core/l10n/content_localization.dart';
import '../data/models/category_model.dart';
import '../core/constants/tts_speed_options.dart';
import '../core/theme/theme_tokens.dart';
import '../data/database/database_helper.dart';
import '../data/models/favorite_model.dart';
import '../data/models/history_model.dart';
import '../data/models/phrase_model.dart';
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

  List<CategoryModel> _categories = [];
  List<PhraseModel> _phrases = [];
  List<FavoriteModel> _favorites = [];
  List<HistoryModel> _history = [];

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
        } else {
          _route = AppRoute.login;
        }
      }
    }
    _loading = false;
    notifyListeners();
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
    final lang = settings['language'] as String?;
    if (lang == 'Filipino') {
      _language = AppLanguage.filipino;
    } else if (lang == 'English') {
      _language = AppLanguage.english;
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

  void setRoute(AppRoute route) {
    _route = route;
    _drawerOpen = false;
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

  Future<void> setLanguage(AppLanguage lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', AppStrings.langCode(lang));
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

  String localizedPhraseText(PhraseModel phrase) => ContentLocalization.phrase(
        phrase.text,
        phrase.categoryKey,
        isBuiltin: phrase.isBuiltin,
        lang: _language,
      );

  String localizedCategoryName(CategoryModel category) =>
      ContentLocalization.category(category.key, category.name, _language);

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
    _theme = TapTalkThemes.appDefault;
    _emergencyContacts = [];
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
    await _repo.addPhrase(
      userId: _user!.id,
      text: text,
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

  Future<void> recordHistory(String text) async {
    if (_user == null || text.trim().isEmpty) return;
    await _repo.addHistory(
      userId: _user!.id,
      text: text,
      categoryKey: _selectedCategoryKey,
    );
    _history = await _repo.getHistory(_user!.id);
    notifyListeners();
  }

  Future<void> deleteHistoryItem(HistoryModel item) async {
    if (_user == null) return;
    await _repo.removeHistory(item.id);
    _history.removeWhere((e) => e.id == item.id);
    notifyListeners();
  }

  Future<void> clearAllHistory() async {
    if (_user == null) return;
    await _repo.clearHistory(_user!.id);
    _history = [];
    notifyListeners();
  }

  String get profileCode =>
      _user == null ? '' : AppRepository.profileCodeFor(_user!.id);

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

  Future<bool> speakText(String text, {bool record = false}) async {
    final spoken = ContentLocalization.phrase(
      text,
      _selectedCategoryKey,
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
    if (ok && record) await recordHistory(spoken);
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
