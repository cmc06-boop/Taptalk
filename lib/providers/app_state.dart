import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../core/l10n/app_strings.dart';
import '../core/utils/auth_validation.dart';
import '../core/utils/phrase_image_storage.dart';
import '../core/l10n/content_localization.dart';
import '../data/models/category_model.dart';
import '../core/navigation/route_transitions.dart';
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
import '../data/default_builtin_content.dart';
import '../data/models/favorite_model.dart';
import '../data/models/history_model.dart';
import '../data/models/enrolled_class_model.dart';
import '../data/models/class_join_request.dart';
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
import '../services/stt_service.dart';
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
  teacherRecentLessons,
  teacherJoinRequests,
}

typedef AppScreenBuilder = Widget Function(AppRoute route);

class _AppNavigatorObserver extends NavigatorObserver {
  _AppNavigatorObserver(this._app);

  final AppState _app;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _app.handleNavigatorPop(route);
  }
}

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState() {
    WidgetsBinding.instance.addObserver(this);
    _bindTtsCallbacks();
    _init();
  }

  final AppRepository _repo = AppRepository(DatabaseHelper.instance);
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  late final NavigatorObserver navigatorObserver = _AppNavigatorObserver(this);
  AppScreenBuilder? _screenBuilder;
  final TtsService tts = TtsService();
  final DeviceSmsService _deviceSms = DeviceSmsService();
  late final NotificationSyncService _notificationSync =
      NotificationSyncService(
        repository: _repo,
        cloudBackend: FirestoreNotificationBackend(),
      );

  bool _loading = true;
  UserModel? _user;
  AppRoute _route = AppRoute.welcome;
  final List<AppRoute> _pageStack = [AppRoute.welcome];
  TapTalkThemeToken _theme = TapTalkThemes.appDefault;
  AppLanguage _language = AppLanguage.english;
  int _languageRevision = 0;
  double _ttsSpeed = TtsSpeedOptions.defaultSpeed;
  String _selectedCategoryKey = 'emotions';
  String? _selectedSubcategoryKey;
  bool _drawerOpen = false;
  bool _routeChanging = false;
  DateTime? _lastSubcategoryBackAt;
  bool _isSpeaking = false;
  String _speakingText = '';
  int? _speakingPhraseId;
  bool _phraseVideoFromViewOnly = false;
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
  bool _interruptingForSpeed = false;
  List<String> _emergencyContacts = [];
  String _profileCode = '';
  String _welcomeFirstName = '';
  String _profileLastName = '';
  bool _hasStoredLastName = false;
  String _address = '';
  int? _age;
  String _gradeLevel = '';
  String _birthdate = '';

  List<CategoryModel> _categories = [];
  List<PhraseModel> _phrases = [];
  List<FavoriteModel> _favorites = [];
  Future<void> _favoriteCloudMutation = Future<void>.value();
  DateTime? _lastFavoriteLocalMutationAt;
  final Set<String> _locallyRemovedFavoriteKeys = {};
  List<HistoryModel> _history = [];
  List<LinkedChildModel> _linkedChildren = [];
  List<ParentNotification> _notifications = [];
  int? _selectedChildId;
  List<EnrolledClassModel> _enrolledClasses = [];
  List<({int id, String name, String code})> _teacherClasses = [];
  List<ClassJoinRequest> _pendingJoinRequests = [];
  int _joinRequestsRevision = 0;
  int _teacherStudentCount = 0;
  final Map<int, int> _teacherClassStudentCounts = {};
  final Set<String> _deletedClassCodes = {};
  int _teacherAlertsRevision = 0;
  int _liveDataRevision = 0;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<User?>? _firebaseAuthRestoreSubscription;
  bool _loggedCloudAuthMissing = false;
  bool _monitoringSyncInFlight = false;
  final Map<int, Future<void>> _monitoringHistoryPullChain = {};
  final Map<int, int> _childMonitoringRevision = {};
  final Map<int, int> _classContentRevision = {};
  final Map<int, DateTime> _classLocalEditAt = {};
  final Map<int, DateTime> _lastOwnClassPushUpdatedAt = {};
  final Map<int, int> _lastAppliedRemoteClassContentMs = {};
  final Map<int, Map<String, DateTime>> _recentDeletedPhraseKeys = {};
  final Map<int, Future<void>> _classContentMergeChain = {};
  Future<void> _personalBoardMergeChain = Future<void>.value();
  final Set<int> _liveClassContentIds = {};
  final Map<int, bool> _classContentPushInFlight = {};
  final Map<int, bool> _classContentPushPending = {};
  Timer? _pendingActivitySyncTimer;
  final Set<int> _liveMonitoredLearnerIds = {};

  bool get loading => _loading;
  UserModel? get user => _user;
  AppRoute get route => _route;
  List<AppRoute> get pageStack => List.unmodifiable(_pageStack);
  bool get canPopRoute =>
      _pageStack.length > 1 ||
      (_route == AppRoute.home && _selectedSubcategoryKey != null);

  void clearRouteHistory() => _resetNavigationStack(_route);

  void _resetNavigationStack(AppRoute route) {
    _pageStack
      ..clear()
      ..add(route);
    _route = route;
  }

  /// Replaces the in-memory stack and the real Navigator (when ready).
  /// During cold start [_loading] is true — only the memory stack is updated
  /// because [MaterialApp.home] will pick up [pageStack.first] once loading ends.
  Future<void> _goToRouteReplacingStack(AppRoute route) async {
    if (_loading) {
      _resetNavigationStack(route);
      return;
    }
    await setRoute(route, replace: true);
  }

  void bindScreenBuilder(AppScreenBuilder builder) => _screenBuilder = builder;

  Route<void> _pageRoute(AppRoute route) {
    final builder = _screenBuilder;
    assert(builder != null, 'Call bindScreenBuilder before navigating.');
    return taptalkPageRoute<void>(
      settings: RouteSettings(name: route.name),
      builder: (_) => builder!(route),
    );
  }

  Future<void> handleSystemBack() async {
    if (_drawerOpen) {
      _drawerOpen = false;
      notifyListeners();
      return;
    }

    if (_route == AppRoute.home && _selectedSubcategoryKey != null) {
      clearSubcategorySelection();
      return;
    }

    final justReturnedToSubcategories =
        _lastSubcategoryBackAt != null &&
        DateTime.now().difference(_lastSubcategoryBackAt!) <
            const Duration(milliseconds: 400);
    if (justReturnedToSubcategories && _route == AppRoute.home) {
      return;
    }

    if (_pageStack.length > 1) {
      await popRoute();
      return;
    }

    final nav = navigatorKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return;
    }

    await SystemNavigator.pop();
  }

  /// Keeps [_pageStack] aligned when a route is popped without [popRoute].
  void handleNavigatorPop(Route<dynamic> route) {
    if (_routeChanging) return;
    if (_pageStack.length <= 1) return;
    if (route.settings.name != _pageStack.last.name) return;
    _pageStack.removeLast();
    _route = _pageStack.last;
    if (_route == AppRoute.chooseCategory) {
      _selectedSubcategoryKey = null;
    }
    _scheduleRouteRefresh(_route);
    notifyListeners();
  }

  bool _isShowing(AppRoute route) {
    final nav = navigatorKey.currentState;
    if (nav == null) return _route == route;
    String? name;
    nav.popUntil((current) {
      name = current.settings.name;
      return true;
    });
    return name == route.name;
  }

  Future<void> _waitForRouteIdle() async {
    var spins = 0;
    while (_routeChanging && spins < 80) {
      await Future<void>.delayed(Duration.zero);
      spins++;
    }
    if (_routeChanging) _routeChanging = false;
  }

  TapTalkThemeToken get theme => _theme;
  AppLanguage get language => _language;
  int get languageRevision => _languageRevision;
  double get ttsSpeed => _ttsSpeed;
  String get selectedCategoryKey => _selectedCategoryKey;
  String? get selectedSubcategoryKey => _selectedSubcategoryKey;

  String get effectivePhraseCategoryKey =>
      _selectedSubcategoryKey ?? _selectedCategoryKey;

  bool get showingSubcategoryPicker =>
      subcategoriesForSelected.isNotEmpty && _selectedSubcategoryKey == null;

  List<CategoryModel> get topLevelCategories =>
      categories.where((c) => c.isTopLevel).toList();

  List<CategoryModel> get subcategoriesForSelected {
    return categories
        .where((c) => c.parentKey == _selectedCategoryKey)
        .toList();
  }

  CategoryModel? get selectedTopLevelCategory {
    for (final c in categories) {
      if (c.key == _selectedCategoryKey) return c;
    }
    return null;
  }

  bool get drawerOpen => _drawerOpen;
  bool get isSpeaking => _isSpeaking;
  String get speakingText => _speakingText;
  int? get speakingPhraseId => _speakingPhraseId;
  int get spokenWordStart => _spokenWordStart;
  int get spokenWordEnd => _spokenWordEnd;

  /// When true, phrase-card videos stay paused so only the View dialog plays.
  bool get phraseVideoFromViewOnly => _phraseVideoFromViewOnly;

  void setPhraseVideoFromViewOnly(bool value) {
    if (_phraseVideoFromViewOnly == value) return;
    _phraseVideoFromViewOnly = value;
    notifyListeners();
  }

  /// Read-along highlight for a composer field only when it matches [spokenText].
  (int start, int end) composerHighlightRange(String composerText) {
    final active = _isSpeaking || _speechPaused;
    if (!active || _speakingText.trim() != composerText.trim()) {
      return (-1, -1);
    }
    return (_spokenWordStart, _spokenWordEnd);
  }

  List<String> get emergencyContacts => List.unmodifiable(_emergencyContacts);
  String get address => _address;
  int? get age => _age;
  String get gradeLevel => _gradeLevel;
  String get birthdate => _birthdate;

  /// First name as stored (sign-up / profile), including multiple given names.
  String get profileFirstName => _welcomeFirstName.trim();

  /// Last name as stored on profile. Extra words in first name stay there.
  String get profileLastName {
    if (_hasStoredLastName) return _profileLastName.trim();
    return '';
  }

  /// First name from sign-up (For Me welcome). Never uses email.
  String welcomeFirstName(AppLanguage lang) {
    final name = _welcomeFirstName.trim();
    if (name.isNotEmpty) return name;
    return AppStrings.defaultLearnerName(lang);
  }

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
  List<ClassJoinRequest> get pendingJoinRequests => _pendingJoinRequests;
  int get pendingJoinRequestCount => _pendingJoinRequests.length;
  int get joinRequestsRevision => _joinRequestsRevision;
  int get teacherStudentCount => _teacherStudentCount;
  int get teacherAlertsRevision => _teacherAlertsRevision;

  int get liveDataRevision => _liveDataRevision;

  int childMonitoringRevision(int learnerUserId) =>
      _childMonitoringRevision[learnerUserId] ?? 0;

  bool isLiveChildMonitoringSyncActive(int learnerUserId) =>
      _notificationSync.isMonitoredLearnerMonitoringSyncActive(learnerUserId);

  int classContentRevision(int classId) => _classContentRevision[classId] ?? 0;
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
    if (showingSubcategoryPicker) return const [];
    final list = _phrases
        .where(
          (p) =>
              p.userId == ownerId &&
              p.categoryKey == effectivePhraseCategoryKey &&
              p.isActive,
        )
        .toList();
    // Large video categories: stable A→Z so cards load consistently.
    if (effectivePhraseCategoryKey == 'emotions' ||
        effectivePhraseCategoryKey == 'home') {
      list.sort((a, b) => a.text.toLowerCase().compareTo(b.text.toLowerCase()));
    }
    return list;
  }

  CategoryModel? get selectedCategory {
    final key = _selectedSubcategoryKey ?? _selectedCategoryKey;
    for (final c in categories) {
      if (c.key == key) return c;
    }
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
      if (_interruptingForSpeed) return;
      _stopReadAlongFallback();
      _isSpeaking = false;
      _spokenWordStart = -1;
      _spokenWordEnd = -1;
      notifyListeners();
    };
    tts.onError = (_) {
      if (!_isActiveSpeakGeneration()) return;
      if (_speechPaused) return;
      if (_interruptingForSpeed) return;
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

  int _currentSpeechCharOffset() {
    final text = _speakingText;
    if (text.isEmpty) return 0;
    if (_spokenWordStart >= 0) {
      return _spokenWordStart.clamp(0, text.length);
    }
    if (_speechHighlightOffset > 0) {
      return _speechHighlightOffset.clamp(0, text.length);
    }
    final ranges = _wordRanges(text);
    if (_readAlongWordIndex > 0 && _readAlongWordIndex < ranges.length) {
      return ranges[_readAlongWordIndex].$1;
    }
    return 0;
  }

  Future<bool> _speakUntilDone({
    required int gen,
    required String fullText,
  }) async {
    var attempts = 0;
    while (attempts < 4) {
      attempts++;
      if (gen != _ttsGeneration || !_isSpeaking || _speechPaused) {
        return false;
      }

      var offset = _currentSpeechCharOffset();
      if (_speechHighlightOffset > offset) {
        offset = _speechHighlightOffset;
      }

      final remaining = fullText
          .substring(offset.clamp(0, fullText.length))
          .trimLeft();
      if (remaining.isEmpty) return true;

      final resumeAt = fullText.indexOf(remaining, offset);
      _speechHighlightOffset = resumeAt >= 0 ? resumeAt : offset;
      _spokenWordStart = -1;
      _spokenWordEnd = -1;
      _startReadAlongFallback(
        fromWordIndex: _wordIndexAtOffset(fullText, _speechHighlightOffset),
      );
      notifyListeners();

      final ok = await tts.speak(remaining, rate: _ttsSpeed, lang: _language);
      if (gen != _ttsGeneration) return false;
      if (ok) {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
          await _waitForWindowsTtsCompletion(
            gen: gen,
            textLength: remaining.length,
          );
        }
        return gen == _ttsGeneration;
      }

      if (!_isSpeaking || _speechPaused) return false;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return false;
  }

  Future<void> _waitForWindowsTtsCompletion({
    required int gen,
    required int textLength,
  }) async {
    final completer = Completer<void>();
    final previousComplete = tts.onComplete;
    tts.onComplete = () {
      previousComplete?.call();
      if (!completer.isCompleted) completer.complete();
    };
    try {
      await completer.future.timeout(
        Duration(milliseconds: (textLength * 130).clamp(2000, 60000)),
        onTimeout: () {},
      );
    } finally {
      tts.onComplete = previousComplete;
    }
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
    _readAlongWordIndex = 0;
    _speakingText = '';
    _speakingPhraseId = null;
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
          _resetNavigationStack(AppRoute.login);
        }
      }
    } catch (e, st) {
      debugPrint('TapTalk init failed: $e\n$st');
      if (_user == null) _resetNavigationStack(AppRoute.welcome);
    } finally {
      if (_user == null) {
        _resetNavigationStack(AppRoute.welcome);
      }
      _loading = false;
      notifyListeners();
      unawaited(_initCloudServicesInBackground());
    }
  }

  /// Firebase (auth + notifications) and TTS — runs after the first screen is shown.
  Future<void> _initCloudServicesInBackground() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        // Windows Firebase Auth restores after the first frame; defer cloud sync.
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        await tts.init();
      } else {
        unawaited(tts.init());
      }
      // Auth (sign up / log in) needs Firebase even when no user is logged in yet.
      await FirebaseService.instance.initialize();
      if (_user != null &&
          (_user!.isLearner || _user!.isParent || _user!.isTeacher) &&
          !await NetworkStatus.isOffline()) {
        try {
          await _restoreAccountFromCloud();
          await _refreshPersonalBoard();
          await _applyCrossDevicePreferencesFromAccount();
          notifyListeners();
        } catch (e, st) {
          debugPrint('Background account restore failed: $e\n$st');
        }
      }
      await _activateMonitoringSync();
    } catch (e, st) {
      debugPrint('TapTalk cloud init failed: $e\n$st');
    }
  }

  /// Starts connectivity-based monitoring sync for the signed-in role.
  Future<void> _activateMonitoringSync() async {
    if (_user == null) return;

    final needsFullCloud =
        _user!.isParent || _user!.isTeacher || _user!.isOnlineAccount;
    final needsMonitoringSync = _user!.isLearner && CloudScope.syncMonitoring;

    if (needsFullCloud || needsMonitoringSync) {
      await _notificationSync.initialize();
    }

    _startMonitoringConnectivitySync();
    unawaited(_flushPendingProfileToCloud());

    if (needsMonitoringSync) {
      await _syncPendingLearnerActivityToCloud();
      await _startLearnerEnrollmentSync();
      await _startLearnerJoinRequestSync();
      _startPendingActivitySyncTimer();
    }

    if (_user!.isOnlineAccount &&
        _hasPersonalBoardRole() &&
        CloudScope.syncMonitoring) {
      await _syncFirebaseSessionAfterRestore();
      await _startPersonalBoardSync();
    }

    if (_user!.isOnlineAccount) {
      await _startUserProfileSync();
    }

    if (!needsFullCloud) return;

    await _syncFirebaseSessionAfterRestore();
    if (_user!.isParent || _user!.isTeacher) {
      if (!await _ensureCloudAuthSession(
        timeout: const Duration(seconds: 15),
      )) {
        debugPrint(
          'Monitoring sync deferred for ${_user!.role}: '
          'sign in again to restore Firebase session.',
        );
        return;
      }
    }
    if (_user!.isParent && CloudScope.notifications) {
      await _syncCloudDataAfterFirebaseReady();
    }
    if (_user!.isParent || _user!.isTeacher) {
      if (_user!.isTeacher) {
        await _syncTeacherClassesFromCloud();
        await _syncTeacherAlertsFromCloud();
        await _startTeacherMonitoringSync();
        await _startTeacherAlertSync();
      }
      if (_user!.isParent) {
        await _startParentChildLinkSync();
      }
      unawaited(_prefetchMonitoredLearnerCachesWithRetry());
      unawaited(_reconcileClassContentLiveSync());
    }
    if (_user!.isLearner && CloudScope.syncMonitoring) {
      unawaited(_reconcileClassContentLiveSync());
    }
  }

  Future<void> _startLearnerEnrollmentSync() async {
    if (_user == null || !_user!.isLearner || !CloudScope.syncMonitoring) {
      return;
    }
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
          unawaited(_reconcileClassContentLiveSync());
          _bumpLiveDataRevision();
        } catch (e, st) {
          debugPrint('Learner enrollment live sync failed: $e\n$st');
        }
      },
    );
  }

  Future<void> _startUserProfileSync() async {
    if (_user == null || !_user!.isOnlineAccount) return;
    final uid = await _resolveAccountFirebaseUid();
    if (uid == null || uid.isEmpty) return;
    await _notificationSync.startUserProfileSync(
      firebaseUid: uid,
      onChanged: (profile) async {
        if (_user == null) return;
        try {
          await _applyLiveUserProfileFromCloud(profile);
        } catch (e, st) {
          debugPrint('User profile live sync failed: $e\n$st');
        }
      },
    );
  }

  Future<void> _applyLiveUserProfileFromCloud(RemoteUserProfile profile) async {
    if (_user == null) return;
    if (await _isProfileCloudPending()) {
      await _flushPendingProfileToCloud();
      return;
    }
    final previousLanguage = _language;

    final updated = await _repo.applyRemoteUserProfile(
      userId: _user!.id,
      profile: profile,
    );
    if (updated == null) return;

    _user = updated;
    final settings = await _repo.getUserSettings(_user!.id);
    _welcomeFirstName = AppRepository.welcomeFirstNameFrom(
      settings: settings,
      fullName: _user!.fullName,
    );
    if (profile.language?.trim().isNotEmpty ?? false) {
      _applyLanguageCode(profile.language!.trim());
    } else {
      _applyLanguageFromSettings(settings);
    }
    _applyThemeFromUser(fallbackThemeKey: profile.themeKey);
    _ttsSpeed = TtsSpeedOptions.snap(
      (settings['tts_speed'] as num?)?.toDouble() ??
          TtsSpeedOptions.defaultSpeed,
    );
    _applyProfileExtrasFromSettings(settings);
    await _markLanguageOnboardingDoneIfRestored();
    await _syncLanguagePref();
    await _syncTtsSpeedPref();

    if (_language != previousLanguage) {
      _languageRevision++;
    }
    notifyListeners();
  }

  void _applyProfileExtrasFromSettings(Map<String, dynamic> settings) {
    _address = (settings['address'] as String?)?.trim() ?? '';
    final ageRaw = settings['age'];
    if (ageRaw is int) {
      _age = ageRaw;
    } else if (ageRaw is num) {
      _age = ageRaw.toInt();
    } else if (ageRaw is String) {
      _age = int.tryParse(ageRaw.trim());
    } else {
      _age = null;
    }
    _gradeLevel = (settings['grade_level'] as String?)?.trim() ?? '';
    _birthdate = (settings['birthdate'] as String?)?.trim() ?? '';
    if (settings.containsKey('last_name')) {
      _profileLastName = (settings['last_name'] as String?)?.trim() ?? '';
      _hasStoredLastName = true;
    } else {
      _profileLastName = '';
      _hasStoredLastName = false;
    }
  }

  Future<void> _startPersonalBoardSync() async {
    if (_user == null ||
        !_hasPersonalBoardRole() ||
        !CloudScope.syncMonitoring) {
      return;
    }
    final uid = await _resolveAccountFirebaseUid();
    if (uid == null || uid.isEmpty) return;
    await _notificationSync.startPersonalBoardSync(
      learnerFirebaseUid: uid,
      onChanged: (snapshot) async {
        if (_user == null) return;
        final task = _personalBoardMergeChain.then((_) async {
          if (_user == null) return;
          if (snapshot.categories.isNotEmpty) {
            await _repo.mergeRemoteLearnerCategories(
              learnerUserId: _user!.id,
              remoteCategories: snapshot.categories,
            );
          }
          if (snapshot.customPhrases.isNotEmpty) {
            await _repo.mergeRemoteLearnerCustomPhrases(
              learnerUserId: _user!.id,
              phrases: snapshot.customPhrases,
            );
            await _repo.dedupeCustomPhrases(_user!.id);
          }
          if (snapshot.favorites.isNotEmpty) {
            // Wait for any in-flight star/unstar push, then skip applying a
            // possibly-stale remote list during the local-toggle grace window.
            await _favoriteCloudMutation;
            if (_user == null) return;
            if (!_favoriteMergeGraceActive) {
              final uid = await _personalBoardCloudUid();
              final favorites = (uid != null && uid.isNotEmpty)
                  ? await _notificationSync.getLearnerFavoritesFromCloud(uid)
                  : snapshot.favorites;
              if (favorites.isNotEmpty) {
                await _repo.mergeRemoteLearnerFavorites(
                  learnerUserId: _user!.id,
                  favorites: favorites,
                  skipRemoteKeys: Set<String>.from(_locallyRemovedFavoriteKeys),
                );
              }
            }
          }
          if (snapshot.speakHistory.isNotEmpty) {
            final settings = await _repo.getUserSettings(_user!.id);
            final clearedAtMs = settings['history_cleared_at_ms'] as int?;
            final retainedHistory = clearedAtMs == null
                ? snapshot.speakHistory
                : snapshot.speakHistory
                      .where(
                        (item) =>
                            item.createdAt.millisecondsSinceEpoch > clearedAtMs,
                      )
                      .toList();
            await _repo.mergeRemoteLearnerSpeakHistory(
              learnerUserId: _user!.id,
              history: retainedHistory,
            );
          }
          await _refreshPersonalBoard();
          _bumpLiveDataRevision();
        });
        _personalBoardMergeChain = task;
        try {
          await task;
        } catch (e, st) {
          debugPrint('Personal board live sync failed: $e\n$st');
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
          _bumpLiveDataRevision();
        } catch (e, st) {
          debugPrint('Parent child link live sync failed: $e\n$st');
        }
      },
    );
  }

  Future<void> _startTeacherMonitoringSync() async {
    if (_user == null || !_user!.isTeacher || !CloudScope.syncMonitoring) {
      return;
    }
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
          _bumpLiveDataRevision();
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
          unawaited(_reconcileClassContentLiveSync());
          _bumpLiveDataRevision();
        } catch (e, st) {
          debugPrint('Teacher class live sync failed: $e\n$st');
        }
      },
    );
    await _startTeacherJoinRequestSync();
  }

  Future<void> _startTeacherJoinRequestSync() async {
    if (_user == null || !_user!.isTeacher || !CloudScope.syncMonitoring) {
      return;
    }
    final teacherFirebaseUid = await _resolveAccountFirebaseUid();
    if (teacherFirebaseUid == null || teacherFirebaseUid.isEmpty) return;
    await _syncJoinRequestsFromCloudForTeacher();
    await _notificationSync.startTeacherJoinRequestSync(
      teacherFirebaseUid: teacherFirebaseUid,
      onChanged: (requests) async {
        if (_user == null || !_user!.isTeacher) return;
        try {
          await _repo.mergeRemoteJoinRequestsForTeacher(
            teacherUserId: _user!.id,
            requests: requests,
          );
          await _loadPendingJoinRequests();
          _joinRequestsRevision++;
          notifyListeners();
        } catch (e, st) {
          debugPrint('Teacher join request live sync failed: $e\n$st');
        }
      },
    );
  }

  Future<void> _startLearnerJoinRequestSync() async {
    if (_user == null || !_user!.isLearner || !CloudScope.syncMonitoring) {
      return;
    }
    final uid = await _learnerFirebaseUidForSync();
    if (uid == null || uid.isEmpty) return;
    await _notificationSync.startLearnerJoinRequestSync(
      learnerFirebaseUid: uid,
      onChanged: (requests) async {
        if (_user == null || !_user!.isLearner) return;
        try {
          await _repo.mergeRemoteJoinRequestsForLearner(
            learnerUserId: _user!.id,
            requests: requests,
          );
          _enrolledClasses = await _repo.getEnrolledClasses(_user!.id);
          _bumpLiveDataRevision();
          notifyListeners();
        } catch (e, st) {
          debugPrint('Learner join request live sync failed: $e\n$st');
        }
      },
    );
  }

  Future<void> _syncJoinRequestsFromCloudForTeacher() async {
    if (_user == null ||
        !_user!.isTeacher ||
        !_notificationSync.isCloudAvailable) {
      return;
    }
    final teacherFirebaseUid = await _resolveAccountFirebaseUid();
    if (teacherFirebaseUid == null || teacherFirebaseUid.isEmpty) return;
    try {
      final remote = await _notificationSync.getJoinRequestsForTeacherFromCloud(
        teacherFirebaseUid,
      );
      await _repo.mergeRemoteJoinRequestsForTeacher(
        teacherUserId: _user!.id,
        requests: remote,
      );
      await _loadPendingJoinRequests();
    } catch (e, st) {
      debugPrint('Teacher join request cloud pull failed: $e\n$st');
    }
  }

  Future<void> _loadPendingJoinRequests() async {
    if (_user == null || !_user!.isTeacher) {
      _pendingJoinRequests = [];
      return;
    }
    _pendingJoinRequests = await _repo.getPendingJoinRequestsForTeacher(
      _user!.id,
    );
  }

  Future<void> refreshPendingJoinRequests({
    bool cloudSyncInBackground = true,
  }) async {
    if (_user == null || !_user!.isTeacher) {
      _pendingJoinRequests = [];
      notifyListeners();
      return;
    }
    await _loadPendingJoinRequests();
    _joinRequestsRevision++;
    notifyListeners();
    if (cloudSyncInBackground) {
      unawaited(
        _syncJoinRequestsFromCloudForTeacher().then((_) async {
          await _loadPendingJoinRequests();
          _joinRequestsRevision++;
          notifyListeners();
        }),
      );
    } else {
      await _syncJoinRequestsFromCloudForTeacher();
      await _loadPendingJoinRequests();
      _joinRequestsRevision++;
      notifyListeners();
    }
  }

  Future<String?> acceptJoinRequest(int requestId) async {
    if (_user == null || !_user!.isTeacher) {
      return AppStrings.notSignedIn(_language);
    }
    final request = await _repo.findJoinRequestById(requestId);
    if (request == null || !request.isPending) {
      return AppStrings.somethingWentWrong(_language);
    }
    if (request.teacherUserId != _user!.id) {
      return AppStrings.somethingWentWrong(_language);
    }
    if (!await _repo.isLearnerEnrolled(
      request.learnerUserId,
      request.classId,
    )) {
      await _repo.enrollLearnerInClass(request.learnerUserId, request.classId);
    }
    final learnerFirebaseUid = request.learnerFirebaseUid?.trim() ?? '';
    final teacherFirebaseUid =
        request.teacherFirebaseUid?.trim() ??
        (await _resolveAccountFirebaseUid()) ??
        '';
    if (learnerFirebaseUid.isNotEmpty && teacherFirebaseUid.isNotEmpty) {
      final teacherName = await _repo.teacherDisplayNameForUserId(_user!.id);
      await _notificationSync.syncClassEnrollment(
        classId: request.classId,
        classCode: request.classCode,
        className: request.className,
        teacherFirebaseUid: teacherFirebaseUid,
        learnerUserId: request.learnerUserId,
        learnerName: request.learnerName,
        learnerFirebaseUid: learnerFirebaseUid,
        teacherName: AppRepository.isGenericAccountName(teacherName)
            ? null
            : teacherName,
      );
    }
    final respondedAt = DateTime.now();
    await _repo.updateJoinRequestStatus(
      requestId: requestId,
      status: ClassJoinRequestStatus.accepted,
      respondedAt: respondedAt,
    );
    if (learnerFirebaseUid.isNotEmpty && teacherFirebaseUid.isNotEmpty) {
      await _notificationSync.syncClassJoinRequest(
        event: ClassJoinRequestCloudEvent(
          classId: request.classId,
          classCode: request.classCode,
          className: request.className,
          teacherFirebaseUid: teacherFirebaseUid,
          teacherUserId: request.teacherUserId,
          learnerUserId: request.learnerUserId,
          learnerName: request.learnerName,
          learnerFirebaseUid: learnerFirebaseUid,
          status: ClassJoinRequest.statusToString(
            ClassJoinRequestStatus.accepted,
          ),
          requestedAt: request.requestedAt,
          respondedAt: respondedAt,
        ),
      );
    }
    await _refreshTeacherClassCounts();
    await _loadPendingJoinRequests();
    _joinRequestsRevision++;
    notifyListeners();
    return null;
  }

  Future<String?> rejectJoinRequest(int requestId) async {
    if (_user == null || !_user!.isTeacher) {
      return AppStrings.notSignedIn(_language);
    }
    final request = await _repo.findJoinRequestById(requestId);
    if (request == null || !request.isPending) {
      return AppStrings.somethingWentWrong(_language);
    }
    if (request.teacherUserId != _user!.id) {
      return AppStrings.somethingWentWrong(_language);
    }
    final respondedAt = DateTime.now();
    await _repo.updateJoinRequestStatus(
      requestId: requestId,
      status: ClassJoinRequestStatus.rejected,
      respondedAt: respondedAt,
    );
    final learnerFirebaseUid = request.learnerFirebaseUid?.trim() ?? '';
    final teacherFirebaseUid =
        request.teacherFirebaseUid?.trim() ??
        (await _resolveAccountFirebaseUid()) ??
        '';
    if (learnerFirebaseUid.isNotEmpty && teacherFirebaseUid.isNotEmpty) {
      await _notificationSync.syncClassJoinRequest(
        event: ClassJoinRequestCloudEvent(
          classId: request.classId,
          classCode: request.classCode,
          className: request.className,
          teacherFirebaseUid: teacherFirebaseUid,
          teacherUserId: request.teacherUserId,
          learnerUserId: request.learnerUserId,
          learnerName: request.learnerName,
          learnerFirebaseUid: learnerFirebaseUid,
          status: ClassJoinRequest.statusToString(
            ClassJoinRequestStatus.rejected,
          ),
          requestedAt: request.requestedAt,
          respondedAt: respondedAt,
        ),
      );
    }
    await _loadPendingJoinRequests();
    _joinRequestsRevision++;
    notifyListeners();
    return null;
  }

  Future<void> _syncTeacherAlertsFromCloud() async {
    if (_user == null || !_user!.isTeacher || !CloudScope.notifications) return;
    await FirebaseService.instance.initialize();
    await _notificationSync.initialize();
    if (!_notificationSync.isCloudAvailable) return;
    final teacherFirebaseUid = await _resolveAccountFirebaseUid();
    if (teacherFirebaseUid == null || teacherFirebaseUid.isEmpty) return;
    await _notificationSync.syncTeacherAlertsFromCloud(
      teacherUserId: _user!.id,
      teacherFirebaseUid: teacherFirebaseUid,
    );
  }

  Future<void> _startTeacherAlertSync() async {
    if (_user == null || !_user!.isTeacher || !CloudScope.notifications) return;
    await FirebaseService.instance.initialize();
    await _notificationSync.initialize();
    if (!_notificationSync.isCloudAvailable) return;
    final teacherFirebaseUid = await _resolveAccountFirebaseUid();
    if (teacherFirebaseUid == null || teacherFirebaseUid.isEmpty) return;
    await _notificationSync.startTeacherAlertSync(
      teacherUserId: _user!.id,
      teacherFirebaseUid: teacherFirebaseUid,
      onChanged: () {
        if (_user == null || !_user!.isTeacher) return;
        _teacherAlertsRevision++;
        notifyListeners();
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
    final settings = await _repo.getUserSettings(_user!.id);
    final hasAccountLanguage =
        settings['language'] is String &&
        (settings['language'] as String).trim().isNotEmpty;

    var languageDone = await _isLanguageOnboardingDone(_user!.id);
    if (!languageDone && hasAccountLanguage) {
      await _setLanguageOnboardingDone(_user!.id, true);
      languageDone = true;
    }
    if (!languageDone) {
      await _goToRouteReplacingStack(AppRoute.chooseLanguage);
      return;
    }
    if (_user!.isLearner) {
      if (_user!.needsTheme) {
        await _goToRouteReplacingStack(AppRoute.chooseTheme);
        return;
      }
      await _ensureStarterData();
      await _goToRouteReplacingStack(AppRoute.chooseCategory);
    } else if (_user!.isParent) {
      await _goToRouteReplacingStack(AppRoute.myChild);
    } else if (_user!.isTeacher) {
      await _goToRouteReplacingStack(AppRoute.teacherDashboard);
    }
  }

  /// Clears in-memory words/phrases/categories so a new login never briefly
  /// shows another account's customized content.
  void _resetLearnerSessionData() {
    _categories = [];
    _phrases = [];
    _favorites = [];
    _locallyRemovedFavoriteKeys.clear();
    _lastFavoriteLocalMutationAt = null;
    _history = [];
    _selectedCategoryKey = 'emotions';
    _selectedSubcategoryKey = null;
    _profileCode = '';
    _enrolledClasses = [];
    _emergencyContacts = [];
    _address = '';
    _age = null;
    _gradeLevel = '';
    _birthdate = '';
    _profileLastName = '';
    _hasStoredLastName = false;
  }

  void _resetAccountSession() {
    _resetLearnerSessionData();
    _linkedChildren = [];
    _notifications = [];
    _selectedChildId = null;
    _teacherClasses = [];
    _pendingJoinRequests = [];
    _joinRequestsRevision = 0;
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
    _welcomeFirstName = AppRepository.welcomeFirstNameFrom(
      settings: settings,
      fullName: _user!.fullName,
    );
    _ttsSpeed = TtsSpeedOptions.snap(
      (settings['tts_speed'] as num?)?.toDouble() ??
          TtsSpeedOptions.defaultSpeed,
    );
    _applyLanguageFromSettings(settings);
    final settingsLanguage = settings['language'];
    final hasSettingsLanguage =
        settingsLanguage is String && settingsLanguage.trim().isNotEmpty;
    if (!hasSettingsLanguage) {
      await _restoreLanguagePref();
    } else {
      await _setLanguageOnboardingDone(_user!.id, true);
    }
    await _syncLanguagePref();
    await _syncTtsSpeedPref();
    final contacts = settings['emergency_contacts'];
    if (contacts is List) {
      _emergencyContacts = AppRepository.normalizeEmergencyContacts(
        contacts.whereType<String>().toList(),
      );
    } else {
      _emergencyContacts = [];
    }
    _applyProfileExtrasFromSettings(settings);

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
      if (_hasPersonalBoardRole() && CloudScope.syncMonitoring) {
        if (cloudSyncInBackground) {
          unawaited(_syncAccountPersonalDataToCloud());
        } else {
          await _pullPersonalBoardFromCloud();
          await _refreshPersonalBoard();
          await _syncAccountPersonalDataToCloud();
        }
      }
    }

    _categories = (await _repo.getCategories(
      userId,
    )).where((c) => c.userId == userId).toList();
    _phrases = (await _repo.getPhrases(
      userId,
    )).where((p) => p.userId == userId).toList();
    _favorites = (await _repo.getFavorites(
      userId,
    )).where((f) => f.userId == userId).toList();
    _history = (await _repo.getHistory(
      userId,
    )).where((h) => h.userId == userId).toList();

    if (_categories.isNotEmpty &&
        !_categories.any((c) => c.key == _selectedCategoryKey)) {
      _selectedCategoryKey = _categories.first.key;
    }
  }

  Future<void> _syncLearnerCloudData() async {
    if (_user == null || !_user!.isLearner) return;
    try {
      if (CloudScope.syncMonitoring) {
        await _pullPersonalBoardFromCloud();
        await _refreshPersonalBoard();
        await _syncLearnerCategoriesToCloud();
        await _syncLearnerCustomPhrasesToCloud();
        await _syncLearnerFavoritesToCloud();
        await _syncLearnerSpeakHistoryToCloud();
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
    if (await NetworkStatus.isOffline() || NetworkStatus.isCloudBlocked) return;
    if (AppRepository.isStubEmail(_user!.email)) return;
    await FirebaseService.instance.initialize();
    await _notificationSync.initialize();
    if (!_notificationSync.isCloudAvailable) return;

    final String? firebaseUid;
    if (_user!.isLearner) {
      firebaseUid = await _learnerFirebaseUidForSync();
    } else {
      if (!await _ensureCloudAuthSession()) return;
      firebaseUid = await _resolveAccountFirebaseUid();
    }
    if (firebaseUid == null || firebaseUid.isEmpty) return;

    String? profileCode;
    if (_user!.isLearner) {
      profileCode = _profileCode.isNotEmpty
          ? _profileCode
          : await _repo.ensureLearnerProfileCode(_user!.id);
    }
    final settings = await _repo.getUserSettings(_user!.id);
    final signupFirstName = (settings['first_name'] as String?)?.trim();
    final themeKey = _user!.themeKey?.trim();
    final resolvedThemeKey = themeKey != null && themeKey.isNotEmpty
        ? themeKey
        : _theme.key;

    await _notificationSync.syncUserProfile(
      RemoteUserProfile(
        firebaseUid: firebaseUid,
        email: _user!.email,
        fullName: _user!.fullName,
        role: _user!.role,
        firstName: signupFirstName?.isNotEmpty == true ? signupFirstName : null,
        themeKey: resolvedThemeKey,
        profileCode: profileCode,
        language: AppStrings.langCode(_language),
        ttsSpeed: _ttsSpeed,
        address: _address.isEmpty ? null : _address,
        age: _age,
        gradeLevel: _gradeLevel.isEmpty ? null : _gradeLevel,
        birthdate: _birthdate.isEmpty ? null : _birthdate,
        lastName: profileLastName,
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

  Future<bool> _isProfileCloudPending() async {
    if (_user == null) return false;
    final settings = await _repo.getUserSettings(_user!.id);
    return settings['profile_cloud_pending'] == true;
  }

  Future<void> _markProfileCloudPending() async {
    if (_user == null || !CloudScope.syncMonitoring) return;
    await _repo.updateUserSettings(_user!.id, profileCloudPending: true);
  }

  Future<void> _clearProfileCloudPending() async {
    if (_user == null) return;
    await _repo.updateUserSettings(_user!.id, profileCloudPending: false);
  }

  /// Saves locally first; cloud upload happens now if online, or later when
  /// connectivity returns.
  Future<void> _enqueueProfileCloudSync() async {
    if (_user == null || !CloudScope.syncMonitoring) return;
    await _markProfileCloudPending();
    unawaited(_flushPendingProfileToCloud());
  }

  Future<void> _flushPendingProfileToCloud() async {
    if (_user == null || !CloudScope.syncMonitoring) return;
    if (!await _isProfileCloudPending()) return;
    if (await NetworkStatus.isOffline() || NetworkStatus.isCloudBlocked) return;
    try {
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
            learnerName: _user!.fullName,
            learnerProfileCode: profileCode,
          );
          await _resyncLearnerEnrollmentsToCloud();
        }
      }
      await _clearProfileCloudPending();
    } catch (e, st) {
      debugPrint('Pending profile cloud sync failed: $e\n$st');
      NetworkStatus.markCloudUnreachable();
    }
  }

  bool _hasPersonalBoardRole() {
    if (_user == null) return false;
    return _user!.isLearner || _user!.isParent || _user!.isTeacher;
  }

  RemoteUserProfile _mergeCloudAccountPreferences({
    required RemoteUserProfile profile,
    RemoteUserProfile? cloudSource,
  }) {
    if (cloudSource == null) return profile;
    final cloudTheme = cloudSource.themeKey?.trim();
    final cloudLanguage = cloudSource.language?.trim();
    return RemoteUserProfile(
      firebaseUid: profile.firebaseUid,
      email: profile.email,
      fullName: profile.fullName,
      role: profile.role,
      firstName: profile.firstName ?? cloudSource.firstName,
      themeKey: cloudTheme != null && cloudTheme.isNotEmpty
          ? cloudTheme
          : profile.themeKey,
      profileCode: profile.profileCode ?? cloudSource.profileCode,
      language: cloudLanguage != null && cloudLanguage.isNotEmpty
          ? cloudLanguage
          : profile.language,
      ttsSpeed: cloudSource.ttsSpeed ?? profile.ttsSpeed,
      address: (profile.address?.trim().isNotEmpty ?? false)
          ? profile.address
          : cloudSource.address,
      age: profile.age ?? cloudSource.age,
      gradeLevel: (profile.gradeLevel?.trim().isNotEmpty ?? false)
          ? profile.gradeLevel
          : cloudSource.gradeLevel,
      birthdate: (profile.birthdate?.trim().isNotEmpty ?? false)
          ? profile.birthdate
          : cloudSource.birthdate,
      lastName: profile.lastName != null
          ? profile.lastName
          : cloudSource.lastName,
    );
  }

  Future<void> _markLanguageOnboardingDoneIfRestored() async {
    if (_user == null) return;
    final settings = await _repo.getUserSettings(_user!.id);
    final raw = settings['language'];
    if (raw is String && raw.trim().isNotEmpty) {
      await _setLanguageOnboardingDone(_user!.id, true);
    }
  }

  Future<void> _applyCrossDevicePreferencesFromAccount() async {
    if (_user == null) return;
    final refreshed = await _repo.findUserById(_user!.id);
    if (refreshed != null) {
      _user = refreshed;
    }
    final settings = await _repo.getUserSettings(_user!.id);
    _applyLanguageFromSettings(settings);
    _applyThemeFromUser();
    await _markLanguageOnboardingDoneIfRestored();
    await _syncLanguagePref();
    await _syncTtsSpeedPref();
  }

  void _applyThemeFromUser({String? fallbackThemeKey}) {
    final key = _user?.themeKey?.trim() ?? fallbackThemeKey?.trim();
    if (key != null && key.isNotEmpty) {
      _theme = TapTalkThemes.byKey(key);
    } else if (_user?.needsTheme == true) {
      _theme = TapTalkThemes.appDefault;
    }
  }

  Future<void> _restoreUserProfileFromCloud() async {
    if (_user == null) return;
    if (await NetworkStatus.isOffline()) return;
    if (await _isProfileCloudPending()) {
      await _flushPendingProfileToCloud();
      if (await _isProfileCloudPending()) return;
    }
    await FirebaseService.instance.initialize();
    await _notificationSync.initialize();
    if (!_notificationSync.isCloudAvailable) return;

    final uid = await _resolveAccountFirebaseUid();
    if (uid == null || uid.isEmpty) return;

    try {
      final cloudSnapshot = await _notificationSync.getUserProfileFromCloud(
        uid,
      );
      var profile = cloudSnapshot;
      if (profile != null &&
          AppRepository.isGenericAccountName(profile.fullName)) {
        profile = null;
      }
      profile ??= await _notificationSync.resolveUserProfileForLogin(
        firebaseUid: uid,
        email: _user!.email.contains('@taptalk.stub')
            ? (FirebaseService.instance.auth?.currentUser?.email ??
                  _user!.email)
            : _user!.email,
      );
      profile = _mergeCloudAccountPreferences(
        profile: profile,
        cloudSource: cloudSnapshot,
      );
      final updated = await _repo.applyRemoteUserProfile(
        userId: _user!.id,
        profile: profile,
      );
      if (updated != null) {
        _user = updated;
        final settings = await _repo.getUserSettings(_user!.id);
        _welcomeFirstName = AppRepository.welcomeFirstNameFrom(
          settings: settings,
          fullName: _user!.fullName,
        );
        if (profile.language?.trim().isNotEmpty ?? false) {
          _applyLanguageCode(profile.language!.trim());
        } else {
          _applyLanguageFromSettings(settings);
        }
        _applyThemeFromUser(fallbackThemeKey: cloudSnapshot?.themeKey);
        _ttsSpeed = TtsSpeedOptions.snap(
          (settings['tts_speed'] as num?)?.toDouble() ??
              TtsSpeedOptions.defaultSpeed,
        );
        _applyProfileExtrasFromSettings(settings);
        await _markLanguageOnboardingDoneIfRestored();
        await _syncLanguagePref();
        await _syncTtsSpeedPref();
      }
    } catch (e, st) {
      debugPrint('Restore user profile from cloud failed: $e\n$st');
    }
  }

  Future<void> _pullPersonalBoardFromCloud() async {
    if (_user == null || !_hasPersonalBoardRole()) return;
    if (!CloudScope.syncMonitoring) return;
    if (await NetworkStatus.isOffline()) return;
    await FirebaseService.instance.initialize();
    await _notificationSync.initialize();
    if (!_notificationSync.isCloudAvailable) return;

    final uid = _user!.isLearner
        ? await _learnerFirebaseUidForSync()
        : (await _ensureCloudAuthSession()
              ? await _resolveAccountFirebaseUid()
              : null);
    if (uid == null || uid.isEmpty) return;

    try {
      final remote = await _notificationSync.getLearnerCategoriesFromCloud(uid);
      if (remote.isNotEmpty) {
        await _repo.mergeRemoteLearnerCategories(
          learnerUserId: _user!.id,
          remoteCategories: remote,
        );
      }
      await _pullLearnerCustomPhrasesFromCloud(_user!.id);
      await _pullLearnerFavoritesFromCloud(_user!.id);
      await _pullLearnerSpeakHistoryFromCloud(_user!.id);
      await _repo.dedupeCustomPhrases(_user!.id);
    } catch (e, st) {
      debugPrint('Pull personal board from cloud failed: $e\n$st');
    }
  }

  Future<void> _restoreAccountFromCloud() async {
    if (_user == null) return;
    if (await NetworkStatus.isOffline()) return;
    await FirebaseService.instance.initialize();
    final isWindows =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    final authUid = await FirebaseService.instance.waitForAuthUid(
      timeout: isWindows
          ? const Duration(seconds: 20)
          : const Duration(seconds: 12),
    );
    if (authUid == null || authUid.isEmpty) {
      debugPrint('Account cloud restore skipped: Firebase auth not ready');
      return;
    }
    if (_user!.firebaseUid == null || _user!.firebaseUid!.isEmpty) {
      await _repo.linkFirebaseUid(_user!.id, authUid);
      _user = _user!.copyWith(firebaseUid: authUid);
    }
    await _restoreUserProfileFromCloud();
    await _pullPersonalBoardFromCloud();
    await _refreshPersonalBoard();
  }

  Future<String?> _personalBoardCloudUid() async {
    if (_user == null || !_hasPersonalBoardRole()) return null;
    if (!CloudScope.syncMonitoring) return null;
    if (await NetworkStatus.isOffline()) return null;
    await FirebaseService.instance.initialize();
    await _notificationSync.initialize();
    if (!_notificationSync.isCloudAvailable) return null;
    if (_user!.isLearner) {
      return _learnerFirebaseUidForSync();
    }
    if (!await _ensureCloudAuthSession()) return null;
    return _resolveAccountFirebaseUid();
  }

  void _syncAccountPersonalDataInBackground() {
    unawaited(() async {
      await _syncAccountPersonalDataToCloud();
      await _refreshPersonalBoard();
      notifyListeners();
    }());
  }

  Future<void> _syncAccountPersonalDataToCloud() async {
    if (_user == null || !_hasPersonalBoardRole()) return;
    if (!CloudScope.syncMonitoring) return;
    try {
      if (_user!.isLearner) {
        if (await _learnerFirebaseUidForSync() == null) return;
      } else if (!await _ensureCloudAuthSession()) {
        return;
      }
      await _syncUserProfileToCloud();
      await _syncPersonalBoardToCloud();
    } catch (e, st) {
      debugPrint('Account personal data cloud sync failed: $e\n$st');
    }
  }

  Future<void> _syncPersonalBoardToCloud() async {
    await _syncLearnerCategoriesToCloud();
    await _syncLearnerCustomPhrasesToCloud();
    await _syncLearnerFavoritesToCloud();
    await _syncLearnerSpeakHistoryToCloud();
  }

  Future<void> _refreshPersonalBoard() async {
    if (_user == null) return;
    final ownerId = _user!.id;
    // Keep builtin phrase media (videos/images) in sync for every
    // category and subcategory on each personal-board refresh.
    await _repo.seedLearnerData(ownerId);
    _categories = (await _repo.getCategories(
      ownerId,
    )).where((c) => c.userId == ownerId).toList();
    _phrases = (await _repo.getPhrases(
      ownerId,
    )).where((p) => p.userId == ownerId).toList();
    _favorites = (await _repo.getFavorites(
      ownerId,
    )).where((f) => f.userId == ownerId).toList();
    _history = (await _repo.getHistory(
      ownerId,
    )).where((h) => h.userId == ownerId).toList();
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
    await _repo.seedLearnerData(_user!.id);
    await _refreshLearnerCollections();
  }

  Future<void> _popUntil(AppRoute target) async {
    final nav = navigatorKey.currentState;
    while (_pageStack.length > 1 && _pageStack.last != target) {
      if (nav != null && nav.canPop()) {
        nav.pop();
      }
      _pageStack.removeLast();
    }
    _route = _pageStack.last;
  }

  void _scheduleRouteRefresh(AppRoute route) {
    // Favorites rely on local toggleFavorite + notifyListeners; auto cloud
    // pull on open was racing and undoing star/unstar. Manual pull-to-refresh
    // still calls refreshFavoritesFromCloud.
    if (_isPersonalBoardRoute(route) &&
        route != AppRoute.favorites &&
        _user != null) {
      unawaited(_refreshPersonalBoard());
    }
  }

  Future<void> setRoute(AppRoute route, {bool replace = false}) async {
    await _waitForRouteIdle();
    _routeChanging = true;
    try {
      if (_drawerOpen) {
        _drawerOpen = false;
        notifyListeners();
      }
      if (_route == route && !replace && _isShowing(route)) return;

      final nav = navigatorKey.currentState;

      if (replace) {
        _resetNavigationStack(route);
        if (nav != null) {
          unawaited(nav.pushAndRemoveUntil(_pageRoute(route), (_) => false));
        }
        _scheduleRouteRefresh(route);
        notifyListeners();
        return;
      }

      if (route == AppRoute.chooseCategory) {
        _selectedSubcategoryKey = null;
      }

      if (_pageStack.contains(route)) {
        await _popUntil(route);
        _scheduleRouteRefresh(route);
        notifyListeners();
        return;
      }

      _pageStack.add(route);
      _route = route;
      if (nav != null) {
        unawaited(nav.push(_pageRoute(route)));
      }
      _scheduleRouteRefresh(route);
      notifyListeners();
    } finally {
      _routeChanging = false;
    }
  }

  Future<bool> popRoute() async {
    await _waitForRouteIdle();
    _routeChanging = true;
    try {
      if (_drawerOpen) {
        _drawerOpen = false;
      }
      if (_route == AppRoute.home && _selectedSubcategoryKey != null) {
        clearSubcategorySelection();
        notifyListeners();
        return true;
      }
      if (_pageStack.length <= 1) return false;

      final nav = navigatorKey.currentState;
      if (nav != null && nav.canPop()) {
        nav.pop();
      }
      if (_pageStack.length > 1) {
        _pageStack.removeLast();
        _route = _pageStack.last;
      }
      if (_route == AppRoute.chooseCategory) {
        _selectedSubcategoryKey = null;
      }
      _scheduleRouteRefresh(_route);
      notifyListeners();
      return true;
    } finally {
      _routeChanging = false;
    }
  }

  void toggleDrawer([bool? open]) {
    _drawerOpen = open ?? !_drawerOpen;
    notifyListeners();
  }

  void selectCategory(String key) {
    if (key == _selectedCategoryKey && _selectedSubcategoryKey != null) {
      _selectedSubcategoryKey = null;
    } else {
      _selectedCategoryKey = key;
      _selectedSubcategoryKey = null;
    }
    notifyListeners();
  }

  void selectSubcategory(String key) {
    _selectedSubcategoryKey = key;
    notifyListeners();
  }

  void clearSubcategorySelection() {
    if (_selectedSubcategoryKey == null) return;
    _selectedSubcategoryKey = null;
    _lastSubcategoryBackAt = DateTime.now();
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
        unawaited(_syncUserProfileToCloud());
      }
    } catch (e, st) {
      debugPrint('setLanguage persist failed: $e\n$st');
    }
  }

  Future<void> setTtsSpeed(double speed, {bool persist = true}) async {
    final snapped = TtsSpeedOptions.snap(speed);
    final changed = snapped != _ttsSpeed;
    _ttsSpeed = snapped;

    if (changed &&
        _isSpeaking &&
        !_speechPaused &&
        _isActiveSpeakGeneration()) {
      _interruptingForSpeed = true;
      unawaited(tts.stop().whenComplete(() => _interruptingForSpeed = false));
    }

    notifyListeners();

    if (!persist) return;
    await _syncTtsSpeedPref();
    if (_user != null) {
      await _repo.updateUserSettings(_user!.id, ttsSpeed: _ttsSpeed);
      _syncAccountPersonalDataInBackground();
    }
  }

  Future<void> setTheme(String themeKey) async {
    _theme = TapTalkThemes.byKey(themeKey);
    if (_user != null) {
      await _repo.updateUserTheme(_user!.id, themeKey);
      _user = _user!.copyWith(themeKey: themeKey);
      unawaited(_syncUserProfileToCloud());
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

    if (offline || !FirebaseService.instance.isAvailable) {
      if (user == null) {
        return AppStrings.loginNeedsInternet(_language);
      }
      final ok = await _repo.verifyLogin(normalizedEmail, password);
      if (!ok) return AppStrings.wrongPassword(_language);
    } else {
      final uid = await FirebaseService.instance.signIn(
        email: normalizedEmail,
        password: password,
      );
      if (uid == null) {
        if (user == null) return AppStrings.emailNotRegistered(_language);
        final ok = await _repo.verifyLogin(normalizedEmail, password);
        if (!ok) return AppStrings.wrongPassword(_language);
        unawaited(
          _linkFirebaseAccountIfAvailable(
            user: user,
            email: normalizedEmail,
            password: password,
          ),
        );
      } else {
        await _notificationSync.initialize();
        var cloudProfile = await _notificationSync.getUserProfileFromCloud(uid);
        final cloudSnapshot = cloudProfile;
        if (cloudProfile != null &&
            AppRepository.isGenericAccountName(cloudProfile.fullName)) {
          cloudProfile = null;
        }
        cloudProfile ??= await _notificationSync.resolveUserProfileForLogin(
          firebaseUid: uid,
          email: normalizedEmail,
        );
        cloudProfile = _mergeCloudAccountPreferences(
          profile: cloudProfile,
          cloudSource: cloudSnapshot,
        );
        user = await _repo.finalizeCloudLoginUser(
          userByEmail: user,
          email: normalizedEmail,
          password: password,
          firebaseUid: uid,
          profile: cloudProfile,
        );
      }
    }

    _user = user;
    if (_user == null) return AppStrings.loginFailed(_language);

    _resetAccountSession();

    if (!offline && FirebaseService.instance.isAvailable) {
      try {
        await _notificationSync.initialize();
        await _restoreAccountFromCloud();
        await _refreshPersonalBoard();
      } catch (e, st) {
        debugPrint('Account restore from cloud failed: $e\n$st');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_id', _user!.id);
    await _applyCrossDevicePreferencesFromAccount();

    if (_user!.isLearner || _user!.isParent || _user!.isTeacher) {
      await _routeUserAfterOnboardingChecks();
    } else {
      await _goToRouteReplacingStack(AppRoute.login);
      notifyListeners();
      return AppStrings.parentTeacherComingSoon(_language);
    }
    notifyListeners();

    try {
      if (_user!.isLearner) {
        await _loadLearnerData(cloudSyncInBackground: false);
        await _ensureStarterData();
      } else if (_user!.isParent) {
        await _loadLearnerData(cloudSyncInBackground: false);
        await _ensureStarterData();
        await _loadLinkedChildren(syncCloudInBackground: true);
        await _notificationSync.initialize();
        await _syncFirebaseSessionAfterRestore();
        await _syncCloudDataAfterFirebaseReady();
      } else if (_user!.isTeacher) {
        await _loadLearnerData(cloudSyncInBackground: false);
        await _ensureStarterData();
        await refreshTeacherClasses(cloudSyncInBackground: false);
        await _notificationSync.initialize();
        await _syncFirebaseSessionAfterRestore();
      }
      if (!offline && FirebaseService.instance.isAvailable) {
        await _pullPersonalBoardFromCloud();
        await _refreshPersonalBoard();
        await _syncAccountPersonalDataToCloud();
      }
      await _applyCrossDevicePreferencesFromAccount();
      unawaited(_activateMonitoringSync());
    } catch (e, st) {
      debugPrint('Post-login data load failed (session is saved): $e\n$st');
    }

    notifyListeners();
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
    required String firstName,
    String lastName = '',
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      return await _registerImpl(
        fullName: fullName,
        firstName: firstName,
        lastName: lastName,
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
    required String firstName,
    String lastName = '',
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
        firstName: firstName,
        lastName: lastName,
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
    _welcomeFirstName = firstName.trim();
    _profileLastName = lastName.trim();
    _hasStoredLastName = true;
    if (role == 'learner') {
      _theme = TapTalkThemes.appDefault;
      await _setLanguageOnboardingDone(_user!.id, false);
      await _setCategoryOnboardingDone(_user!.id, false);
      await _goToRouteReplacingStack(AppRoute.chooseLanguage);
    } else if (role == 'parent') {
      _theme = TapTalkThemes.byKey(_user!.themeKey ?? 'mint_green');
      await _setLanguageOnboardingDone(_user!.id, false);
      await _goToRouteReplacingStack(AppRoute.chooseLanguage);
    } else if (role == 'teacher') {
      _theme = TapTalkThemes.byKey(_user!.themeKey ?? 'mint_green');
      await _setLanguageOnboardingDone(_user!.id, false);
      await _goToRouteReplacingStack(AppRoute.chooseLanguage);
    } else {
      await _goToRouteReplacingStack(AppRoute.login);
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
      final uid = await FirebaseService.instance
          .provisionAuthAccountForPasswordReset(email: normalizedEmail);
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
    _pendingActivitySyncTimer?.cancel();
    _pendingActivitySyncTimer = null;
    _liveMonitoredLearnerIds.clear();
    _childMonitoringRevision.clear();
    _classContentRevision.clear();
    _classLocalEditAt.clear();
    _lastOwnClassPushUpdatedAt.clear();
    _lastAppliedRemoteClassContentMs.clear();
    _recentDeletedPhraseKeys.clear();
    _classContentMergeChain.clear();
    _classContentPushInFlight.clear();
    _classContentPushPending.clear();
    _liveClassContentIds.clear();
    _liveDataRevision = 0;
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    await _firebaseAuthRestoreSubscription?.cancel();
    _firebaseAuthRestoreSubscription = null;
    _loggedCloudAuthMissing = false;
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
    await _goToRouteReplacingStack(AppRoute.welcome);
    _drawerOpen = false;
    notifyListeners();
  }

  Future<void> completeLanguageSelection(AppLanguage lang) async {
    await setLanguage(lang);
    if (_user != null) {
      await _setLanguageOnboardingDone(_user!.id, true);
    }
    if (_user?.isLearner ?? false) {
      await setRoute(AppRoute.chooseTheme, replace: true);
    } else if (_user?.isParent ?? false) {
      await setRoute(AppRoute.myChild, replace: true);
    } else if (_user?.isTeacher ?? false) {
      await setRoute(AppRoute.teacherDashboard, replace: true);
    } else {
      notifyListeners();
    }
  }

  Future<void> completeThemeSelection(String themeKey) async {
    await setTheme(themeKey);
    await setRoute(AppRoute.chooseCategory, replace: true);
  }

  Future<void> completeCategorySelection(String categoryKey) async {
    selectCategory(categoryKey);
    if (_user != null) {
      unawaited(_setCategoryOnboardingDone(_user!.id, true));
    }
    if (_isShowing(AppRoute.home)) {
      notifyListeners();
      return;
    }

    await _waitForRouteIdle();
    _routeChanging = true;
    try {
      if (_pageStack.isNotEmpty && _pageStack.last == AppRoute.home) {
        _pageStack.removeLast();
        _route = _pageStack.last;
      }
      _pageStack.add(AppRoute.home);
      _route = AppRoute.home;
      final nav = navigatorKey.currentState;
      if (nav != null) {
        unawaited(nav.push(_pageRoute(AppRoute.home)));
      }
      _scheduleRouteRefresh(AppRoute.home);
      notifyListeners();
    } finally {
      _routeChanging = false;
    }
  }

  Future<String?> addCategory(String name) async {
    if (_user == null) return AppStrings.notSignedIn(_language);
    try {
      final cat = await _repo.addCategory(_user!.id, name);
      if (_user!.isLearner || _user!.isParent || _user!.isTeacher) {
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

  bool isCustomCategory(CategoryModel category) => !DefaultBuiltinContent
      .defaultCategories
      .any((entry) => entry.$1 == category.key);

  Future<void> deleteCustomCategories(Iterable<String> keys) async {
    if (_user == null) return;
    final allowed = _categories
        .where(isCustomCategory)
        .map((category) => category.key)
        .toSet();
    final deleting = keys.where(allowed.contains).toSet();
    if (deleting.isEmpty) return;
    await _repo.deleteCustomCategories(_user!.id, deleting);
    await _refreshPersonalBoard();
    notifyListeners();
    await _pushLearnerCategoriesToCloud();
    await _pushLearnerCustomPhrasesToCloud();
    await _pushLearnerFavoritesToCloud();
  }

  Future<void> renameCustomCategory(CategoryModel category, String name) async {
    if (_user == null || !isCustomCategory(category) || name.trim().isEmpty) {
      return;
    }
    await _repo.renameCategory(_user!.id, category.key, name);
    await _refreshPersonalBoard();
    notifyListeners();
    unawaited(_pushLearnerCategoriesToCloud());
  }

  Future<String?> addPhrase(String text, {String? imagePath}) async {
    if (_user == null || text.trim().isEmpty) return null;
    if (showingSubcategoryPicker) return null;
    final savedImagePath = await persistPhraseImageIfNeeded(imagePath);
    final stored = text.trim();
    await _repo.addPhrase(
      userId: _user!.id,
      text: stored,
      categoryKey: effectivePhraseCategoryKey,
      imagePath: savedImagePath,
    );
    await _refreshPersonalBoard();
    notifyListeners();
    if (_user!.isLearner || _user!.isParent || _user!.isTeacher) {
      unawaited(_pushLearnerCustomPhrasesToCloud());
    }
    return null;
  }

  Future<void> deletePhrase(PhraseModel phrase) async {
    if (_user == null || phrase.userId != _user!.id) return;

    final removedKey =
        '${phrase.text.trim().toLowerCase()}__${phrase.categoryKey}';
    _phrases = _phrases.where((p) => p.id != phrase.id).toList();
    _favorites = _favorites
        .where((f) => f.phraseId != phrase.id && f.dedupeKey != removedKey)
        .toList();
    notifyListeners();

    if (!phrase.isBuiltin) {
      await _repo.deletePhrase(_user!.id, phrase.id);
    }
    await _refreshPersonalBoard();
    notifyListeners();
    if (!phrase.isBuiltin &&
        (_user!.isLearner || _user!.isParent || _user!.isTeacher)) {
      await _pushLearnerCustomPhrasesToCloud();
      await _pushLearnerFavoritesToCloud();
    }
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
    if (ok && (_user!.isLearner || _user!.isParent || _user!.isTeacher)) {
      unawaited(_pushLearnerCustomPhrasesToCloud());
    }
    return ok;
  }

  bool isFavorite(PhraseModel phrase) {
    final key = _favoriteDedupeKey(phrase.text, phrase.categoryKey);
    return _favorites.any(
      (f) => _favoriteDedupeKey(f.phraseText, f.categoryKey) == key,
    );
  }

  int? favoriteIdFor(PhraseModel phrase) {
    final key = _favoriteDedupeKey(phrase.text, phrase.categoryKey);
    for (final f in _favorites) {
      if (_favoriteDedupeKey(f.phraseText, f.categoryKey) == key) return f.id;
    }
    return null;
  }

  String _favoriteDedupeKey(String text, String categoryKey) {
    return '${AppRepository.storedUserText(text).toLowerCase()}__'
        '${AppRepository.normalizeCategoryKey(categoryKey)}';
  }

  Future<void> toggleFavorite(PhraseModel phrase) async {
    if (_user == null || phrase.userId != _user!.id) return;
    final key = _favoriteDedupeKey(phrase.text, phrase.categoryKey);
    final favId = favoriteIdFor(phrase);
    if (favId != null) {
      // Update every listener immediately (Home star and Favorites filters),
      // then reconcile with the persisted list below.
      _favorites = _favorites.where((f) => f.id != favId).toList();
      _locallyRemovedFavoriteKeys.add(key);
      notifyListeners();
      await _repo.removeFavorite(favId);
    } else {
      _locallyRemovedFavoriteKeys.remove(key);
      final added = await _repo.addFavorite(
        userId: _user!.id,
        phraseText: phrase.text,
        categoryKey: phrase.categoryKey,
        phraseId: phrase.isBuiltin ? null : phrase.id,
        imagePath: phrase.imagePath,
      );
      _favorites = [
        ..._favorites.where(
          (f) =>
              _favoriteDedupeKey(f.phraseText, f.categoryKey) !=
              _favoriteDedupeKey(added.phraseText, added.categoryKey),
        ),
        added,
      ];
      notifyListeners();
    }
    _lastFavoriteLocalMutationAt = DateTime.now();
    _favorites = await _repo.getFavorites(_user!.id);
    notifyListeners();
    final cloudMutation = _pushLearnerFavoritesToCloud();
    _favoriteCloudMutation = cloudMutation;
    await cloudMutation;
  }

  bool get _favoriteMergeGraceActive {
    final at = _lastFavoriteLocalMutationAt;
    if (at == null) return false;
    return DateTime.now().difference(at) < const Duration(seconds: 20);
  }

  Future<void> refreshFavoritesFromCloud() async {
    if (_user == null || !_hasPersonalBoardRole()) return;
    await _favoriteCloudMutation;
    // Right after a local star/unstar, keep the local list so a stale cloud
    // read cannot undo the toggle the user just made.
    if (!_favoriteMergeGraceActive) {
      await _pullLearnerFavoritesFromCloud(_user!.id);
    }
    _favorites = (await _repo.getFavorites(
      _user!.id,
    )).where((f) => f.userId == _user!.id).toList();
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
    final cloudCategoryKey =
        AppRepository.isLessonCategoryKey(storedCategoryKey)
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
      unawaited(_syncLearnerSpeakHistoryToCloud());
    }
  }

  Future<String?> _learnerFirebaseUidForSync() async {
    if (_user == null || !_user!.isLearner) return null;
    final stored = _user!.firebaseUid?.trim();
    if (stored != null && stored.isNotEmpty) return stored;

    final uid = FirebaseService.instance.currentUid;
    if (uid != null && uid.isNotEmpty) {
      await _repo.linkFirebaseUid(_user!.id, uid);
      _user = _user!.copyWith(firebaseUid: uid);
      return uid;
    }
    if (!FirebaseService.instance.isAvailable) return null;
    final restored = await FirebaseService.instance.waitForAuthUid(
      timeout: !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
          ? const Duration(seconds: 20)
          : const Duration(seconds: 8),
    );
    if (restored != null && restored.isNotEmpty) {
      await _repo.linkFirebaseUid(_user!.id, restored);
      _user = _user!.copyWith(firebaseUid: restored);
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
    final effectiveCategoryKey = AppRepository.isLessonCategoryKey(categoryKey)
        ? categoryKey
        : AppRepository.normalizeCategoryKey(categoryKey);
    final syncKey = AppRepository.remoteActivitySyncKey(
      createdAt: createdAt,
      phraseText: phraseText,
      categoryKey: effectiveCategoryKey,
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
      await _flushPendingProfileToCloud();
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
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
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
    await _flushPendingProfileToCloud();

    if (_user!.isOnlineAccount &&
        _hasPersonalBoardRole() &&
        CloudScope.syncMonitoring) {
      await _startPersonalBoardSync();
    }
    if (_user!.isOnlineAccount) {
      await _startUserProfileSync();
    }

    if (_user!.isLearner && CloudScope.syncMonitoring) {
      await _syncLearnerCloudData();
      await refreshEnrolledClasses(cloudSyncInBackground: false);
      await _startLearnerEnrollmentSync();
      await _reconcileClassContentLiveSync();
      return;
    }
    if (_user!.isParent || _user!.isTeacher) {
      await _syncFirebaseSessionAfterRestore();
      if (_user!.isParent) {
        await refreshLinkedChildren(cloudSyncInBackground: false);
        await _startParentNotificationSync();
        await _startParentChildLinkSync();
      }
      if (_user!.isTeacher) {
        await refreshTeacherClasses(cloudSyncInBackground: false);
        await _syncTeacherAlertsFromCloud();
        await _startTeacherMonitoringSync();
        await _startTeacherAlertSync();
      }
      await _prefetchMonitoredLearnerCachesWithRetry();
      await _reconcileClassContentLiveSync();
    }
  }

  void _bumpLiveDataRevision() {
    _liveDataRevision++;
    notifyListeners();
  }

  void _markClassLocallyEdited(int classId) {
    _classLocalEditAt[classId] = DateTime.now();
  }

  void _notifyClassContentChanged(int classId) {
    _classContentRevision[classId] = (_classContentRevision[classId] ?? 0) + 1;
    notifyListeners();
  }

  Future<void> _publishClassContentChange(int classId) async {
    _notifyClassContentChanged(classId);
    await _drainClassContentPush(classId);
  }

  void _enqueueClassContentPush(int classId) {
    if (_classContentPushInFlight[classId] == true) {
      _classContentPushPending[classId] = true;
      return;
    }
    unawaited(_drainClassContentPush(classId));
  }

  Future<void> _drainClassContentPush(int classId) async {
    _classContentPushInFlight[classId] = true;
    try {
      while (true) {
        _classContentPushPending[classId] = false;
        var ok = false;
        for (var attempt = 0; attempt < 3 && !ok; attempt++) {
          if (attempt > 0) {
            await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
          }
          ok = await _pushClassContentToCloud(classId);
        }
        if (_classContentPushPending[classId] != true) break;
      }
    } finally {
      _classContentPushInFlight[classId] = false;
    }
  }

  bool _shouldApplyRemoteClassContent(int classId, DateTime remoteUpdatedAt) {
    if (_user == null || !_user!.isTeacher) return true;
    if (_classContentPushInFlight[classId] == true ||
        _classContentPushPending[classId] == true) {
      return false;
    }
    final localEditAt = _classLocalEditAt[classId];
    if (localEditAt != null && !remoteUpdatedAt.isAfter(localEditAt)) {
      return false;
    }
    final lastPush = _lastOwnClassPushUpdatedAt[classId];
    if (lastPush != null && remoteUpdatedAt.isBefore(lastPush)) {
      return false;
    }
    return true;
  }

  Set<String> _blockedPhraseKeysForClass(int classId) {
    final map = _recentDeletedPhraseKeys[classId];
    if (map == null || map.isEmpty) return const {};
    final cutoff = DateTime.now().subtract(const Duration(minutes: 2));
    map.removeWhere((_, deletedAt) => deletedAt.isBefore(cutoff));
    if (map.isEmpty) {
      _recentDeletedPhraseKeys.remove(classId);
      return const {};
    }
    return map.keys.toSet();
  }

  void _markLessonPhraseDeleted(int classId, String? phraseKey) {
    final key = phraseKey?.trim() ?? '';
    if (key.isEmpty) return;
    _recentDeletedPhraseKeys.putIfAbsent(classId, () => {})[key] =
        DateTime.now();
  }

  bool _shouldSkipOwnClassContentEcho(int classId, DateTime remoteUpdatedAt) {
    if (_user == null || !_user!.isTeacher) return false;
    final own = _lastOwnClassPushUpdatedAt[classId];
    if (own == null) return false;
    return remoteUpdatedAt.difference(own).inMilliseconds.abs() <= 1500;
  }

  Future<void> _applyRemoteClassContent(
    int classId,
    RemoteClassContent content,
  ) async {
    if (content.lessons.isEmpty) return;
    if (!_shouldApplyRemoteClassContent(classId, content.updatedAt)) return;
    if (_shouldSkipOwnClassContentEcho(classId, content.updatedAt)) return;

    final previous = _classContentMergeChain[classId] ?? Future<void>.value();
    final task = previous.then((_) async {
      return _repo.mergeRemoteClassContent(
        classId: classId,
        content: content,
        blockedPhraseKeys: _blockedPhraseKeysForClass(classId),
        pruneStalePhrases: _user?.isTeacher != true,
      );
    });
    _classContentMergeChain[classId] = task.then((_) {});
    try {
      final changed = await task;
      if (changed) {
        _classContentRevision[classId] =
            (_classContentRevision[classId] ?? 0) + 1;
        if (_user?.isLearner == true) {
          await _loadEnrolledClasses();
        }
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('Apply remote class content failed: $e\n$st');
    }
  }

  Future<void> _reconcileClassContentLiveSync() async {
    if (_user == null || !CloudScope.syncMonitoring) return;
    final desiredClassIds = <int>{};
    if (_user!.isLearner) {
      final classes = await _repo.getEnrolledClasses(_user!.id);
      for (final enrolled in classes) {
        desiredClassIds.add(enrolled.classId);
        await startLiveClassContentSync(
          classId: enrolled.classId,
          classCode: enrolled.classCode,
        );
      }
    } else if (_user!.isTeacher) {
      final classes = await _repo.getTeacherClasses(_user!.id);
      for (final teacherClass in classes) {
        desiredClassIds.add(teacherClass.id);
        await startLiveClassContentSync(
          classId: teacherClass.id,
          classCode: teacherClass.code,
        );
      }
    } else {
      return;
    }
    final staleIds = _liveClassContentIds
        .where((id) => !desiredClassIds.contains(id))
        .toList();
    for (final classId in staleIds) {
      await stopLiveClassContentSync(classId);
    }
  }

  Future<void> stopLiveClassContentSync(int classId) async {
    _liveClassContentIds.remove(classId);
    await _notificationSync.stopClassContentSync(classId);
  }

  /// Real-time Firestore listener for lesson phrase updates on enrolled classes.
  Future<void> startLiveClassContentSync({
    required int classId,
    required String classCode,
  }) async {
    if (_user == null || (!_user!.isLearner && !_user!.isTeacher)) return;
    if (!CloudScope.syncMonitoring) return;
    if (!_liveClassContentIds.add(classId)) return;

    await FirebaseService.instance.initialize();
    await _notificationSync.initialize();
    if (!_notificationSync.isCloudAvailable) {
      _liveClassContentIds.remove(classId);
      return;
    }

    final normalized = AppRepository.normalizeClassCode(classCode);
    if (!AppRepository.isValidClassCodeFormat(normalized)) {
      _liveClassContentIds.remove(classId);
      return;
    }

    await _notificationSync.startClassContentSync(
      classId: classId,
      classCode: normalized,
      onChanged: (content) async {
        if (content == null) return;
        await _applyRemoteClassContent(classId, content);
      },
    );
  }

  void _bumpChildMonitoringRevision(int learnerUserId) {
    _childMonitoringRevision[learnerUserId] =
        (_childMonitoringRevision[learnerUserId] ?? 0) + 1;
    _bumpLiveDataRevision();
  }

  void _startPendingActivitySyncTimer() {
    _pendingActivitySyncTimer?.cancel();
    if (_user == null || !_user!.isLearner || !CloudScope.syncMonitoring) {
      return;
    }
    _pendingActivitySyncTimer = Timer.periodic(
      MonitoringConstants.pendingActivitySyncInterval,
      (_) => unawaited(_syncPendingLearnerActivityToCloud()),
    );
  }

  /// Real-time Firestore listener while a parent/teacher views learner monitoring.
  Future<void> startLiveChildMonitoringSync(int learnerUserId) async {
    if (_user == null || (!_user!.isParent && !_user!.isTeacher)) return;
    if (!CloudScope.syncMonitoring) return;

    await FirebaseService.instance.initialize();
    await _notificationSync.initialize();
    if (!_notificationSync.isCloudAvailable) return;
    if (!await _ensureCloudAuthSession()) return;

    final uid = await _resolveLearnerFirebaseUid(
      learnerUserId,
      forMonitoring: true,
    );
    if (uid == null || uid.isEmpty) return;

    _liveMonitoredLearnerIds.add(learnerUserId);

    if (!_notificationSync.isMonitoredLearnerBoardSyncActive(learnerUserId)) {
      await _notificationSync.startMonitoredLearnerBoardSync(
        learnerUserId: learnerUserId,
        learnerFirebaseUid: uid,
        onChanged: (snapshot) async {
          final changed = await _mergeMonitoredLearnerBoardSnapshot(
            learnerUserId: learnerUserId,
            snapshot: snapshot,
          );
          if (changed) {
            _bumpChildMonitoringRevision(learnerUserId);
          }
        },
      );
    }

    if (!_notificationSync.isMonitoredLearnerActivitySyncActive(
      learnerUserId,
    )) {
      await _notificationSync.startMonitoredLearnerActivitySync(
        learnerUserId: learnerUserId,
        learnerFirebaseUid: uid,
        onChanged: (activities) async {
          if (activities.isEmpty) return;
          await _mergeMonitoredLearnerActivities(
            learnerUserId: learnerUserId,
            activities: activities,
          );
          _bumpChildMonitoringRevision(learnerUserId);
        },
      );
    }
  }

  Future<void> stopLiveChildMonitoringSync(int learnerUserId) async {
    _liveMonitoredLearnerIds.remove(learnerUserId);
    await _notificationSync.stopMonitoredLearnerBoardSync(learnerUserId);
    await _notificationSync.stopMonitoredLearnerActivitySync(learnerUserId);
  }

  /// Merges phrase taps from `learner_activity` into local history for monitoring.
  Future<bool> _mergeMonitoredLearnerActivities({
    required int learnerUserId,
    required List<RemoteLearnerActivity> activities,
  }) async {
    if (activities.isEmpty) return false;
    final inserted = await _repo.mergeRemoteLearnerActivities(
      learnerUserId: learnerUserId,
      activities: activities,
    );
    return inserted > 0;
  }

  /// Merges learner_profiles board data into local SQLite for monitoring.
  Future<bool> _mergeMonitoredLearnerBoardSnapshot({
    required int learnerUserId,
    required RemoteLearnerPersonalBoardSnapshot snapshot,
  }) async {
    var changed = false;
    if (snapshot.categories.isNotEmpty) {
      await _repo.mergeRemoteLearnerCategories(
        learnerUserId: learnerUserId,
        remoteCategories: snapshot.categories,
      );
      changed = true;
    }
    if (snapshot.customPhrases.isNotEmpty) {
      final before = (await _repo.getCustomPhraseAdditions(
        learnerUserId: learnerUserId,
      )).length;
      await _repo.mergeRemoteLearnerCustomPhrases(
        learnerUserId: learnerUserId,
        phrases: snapshot.customPhrases,
      );
      await _repo.dedupeCustomPhrases(learnerUserId);
      final after = (await _repo.getCustomPhraseAdditions(
        learnerUserId: learnerUserId,
      )).length;
      if (after != before) changed = true;
    }
    if (snapshot.speakHistory.isNotEmpty) {
      final inserted = await _repo.mergeRemoteLearnerSpeakHistory(
        learnerUserId: learnerUserId,
        history: snapshot.speakHistory,
      );
      if (inserted > 0) changed = true;
    }
    if (changed) {
      await _repo.dedupeMonitoringHistory(learnerUserId);
    }
    return changed;
  }

  /// Pulls learner phrase taps from `learner_activity` into local history.
  Future<List<RemoteLearnerActivity>> _fetchLearnerActivitiesForMonitoring(
    int learnerUserId, {
    bool full = true,
    DateTime? rangeStart,
  }) async {
    if (!CloudScope.syncMonitoring) return const [];
    if (await NetworkStatus.isOffline()) return const [];
    await FirebaseService.instance.initialize();
    await _notificationSync.initialize();
    if (!_notificationSync.isCloudAvailable) return const [];
    if (_user != null && (_user!.isParent || _user!.isTeacher)) {
      if (!await _ensureCloudAuthSession()) return const [];
    }
    final learnerFirebaseUid = await _resolveLearnerFirebaseUid(
      learnerUserId,
      forMonitoring: true,
    );
    if (learnerFirebaseUid == null || learnerFirebaseUid.isEmpty) {
      return const [];
    }
    try {
      final activityRangeStart =
          rangeStart ??
          (full
              ? MonitoringConstants.cloudActivityPullRangeStart()
              : DateTime.now().subtract(
                  MonitoringConstants.monitoringIncrementalLookback,
                ));
      final activityTimeout = full
          ? MonitoringConstants.monitoringPullTimeout
          : MonitoringConstants.monitoringIncrementalPullTimeout;
      return await _notificationSync
          .getLearnerActivitiesFromCloud(
            learnerFirebaseUid: learnerFirebaseUid,
            rangeStart: activityRangeStart,
            rangeEnd: MonitoringConstants.cloudActivityPullRangeEnd(),
          )
          .timeout(activityTimeout);
    } catch (e, st) {
      debugPrint('Fetch learner activities for monitoring failed: $e\n$st');
      return const [];
    }
  }

  Future<bool> _pullLearnerActivitiesForMonitoring(
    int learnerUserId, {
    bool full = true,
  }) async {
    final activities = await _fetchLearnerActivitiesForMonitoring(
      learnerUserId,
      full: full,
    );
    if (activities.isEmpty) return false;
    return _mergeMonitoredLearnerActivities(
      learnerUserId: learnerUserId,
      activities: activities,
    );
  }

  /// Pulls learner_profiles board data and learner_activity taps into SQLite.
  Future<bool> _pullLearnerMonitoringBoardFromCloud(
    int learnerUserId, {
    bool full = true,
  }) async {
    if (!CloudScope.syncMonitoring) return false;
    if (await NetworkStatus.isOffline()) return false;
    await FirebaseService.instance.initialize();
    await _notificationSync.initialize();
    if (!_notificationSync.isCloudAvailable) return false;
    if (_user != null && (_user!.isParent || _user!.isTeacher)) {
      if (!await _ensureCloudAuthSession()) return false;
    }
    final learnerFirebaseUid = await _resolveLearnerFirebaseUid(
      learnerUserId,
      forMonitoring: true,
    );
    if (learnerFirebaseUid == null || learnerFirebaseUid.isEmpty) {
      debugPrint(
        'Pull learner monitoring board skipped: no Firebase UID for user $learnerUserId',
      );
      return false;
    }
    try {
      final results = await Future.wait([
        _notificationSync
            .getLearnerCategoriesFromCloud(learnerFirebaseUid)
            .timeout(const Duration(seconds: 15)),
        _notificationSync
            .getLearnerCustomPhrasesFromCloud(learnerFirebaseUid)
            .timeout(const Duration(seconds: 15)),
        _notificationSync
            .getLearnerSpeakHistoryFromCloud(learnerFirebaseUid)
            .timeout(const Duration(seconds: 15)),
      ]);
      final boardChanged = await _mergeMonitoredLearnerBoardSnapshot(
        learnerUserId: learnerUserId,
        snapshot: RemoteLearnerPersonalBoardSnapshot(
          categories: results[0] as List<RemoteLearnerCategory>,
          customPhrases: results[1] as List<RemoteLearnerCustomPhrase>,
          speakHistory: results[2] as List<RemoteLearnerSpeakHistory>,
        ),
      );
      final activityChanged = await _pullLearnerActivitiesForMonitoring(
        learnerUserId,
        full: full,
      );
      return boardChanged || activityChanged;
    } catch (e, st) {
      debugPrint('Pull learner monitoring board failed: $e\n$st');
      return false;
    }
  }

  /// Pulls learner monitoring data from cloud into local SQLite for monitoring views.
  Future<void> _syncLearnerMonitoringBoardFromCloud(
    int learnerUserId, {
    bool full = true,
  }) async {
    final prior =
        _monitoringHistoryPullChain[learnerUserId] ?? Future<void>.value();
    final task = prior.then((_) async {
      final changed = await _pullLearnerMonitoringBoardFromCloud(
        learnerUserId,
        full: full,
      );
      if (changed) {
        _bumpChildMonitoringRevision(learnerUserId);
      }
    });
    _monitoringHistoryPullChain[learnerUserId] = task;
    try {
      await task;
    } finally {
      if (identical(_monitoringHistoryPullChain[learnerUserId], task)) {
        _monitoringHistoryPullChain.remove(learnerUserId);
      }
    }
  }

  Future<void> _prefetchMonitoredLearnerCachesWithRetry() async {
    for (var attempt = 0; attempt < 4; attempt++) {
      if (_user == null || (!_user!.isParent && !_user!.isTeacher)) return;
      await FirebaseService.instance.initialize();
      await _notificationSync.initialize();
      if (_notificationSync.isCloudAvailable &&
          !await NetworkStatus.isOffline()) {
        await _prefetchMonitoredLearnerCaches();
        return;
      }
      if (attempt < 3) {
        await Future<void>.delayed(Duration(seconds: 2 * (attempt + 1)));
      }
    }
  }

  Future<void> _prefetchMonitoredLearnerCaches() async {
    if (_user == null) return;
    if (await NetworkStatus.isOffline() ||
        !_notificationSync.isCloudAvailable) {
      return;
    }
    if (_user!.isParent || _user!.isTeacher) {
      if (!await _ensureCloudAuthSession()) return;
    }
    if (_user!.isParent) {
      if (_linkedChildren.isEmpty) {
        await _loadLinkedChildren(syncCloudInBackground: false);
      }
      final learnerIds = _linkedChildren.map((c) => c.learnerId).toList();
      if (learnerIds.isNotEmpty) {
        await Future.wait(
          learnerIds.map((id) => refreshChildMonitoringData(id)),
        );
      }
    }
    if (_user!.isTeacher) {
      await _syncTeacherClassesFromCloud();
      final students = await _repo.getTeacherClassStudents(_user!.id);
      final learnerIds = <int>[];
      final seen = <int>{};
      for (final student in students) {
        if (seen.add(student.learnerId)) {
          learnerIds.add(student.learnerId);
        }
      }
      if (learnerIds.isNotEmpty) {
        await Future.wait(
          learnerIds.map((id) => refreshChildMonitoringData(id)),
        );
      }
    }
    if (_liveMonitoredLearnerIds.isNotEmpty) {
      await Future.wait(
        _liveMonitoredLearnerIds.map(
          (id) => refreshChildMonitoringData(id, full: false),
        ),
      );
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
    final userId = _user!.id;
    final clearedAtMs = DateTime.now().millisecondsSinceEpoch;
    await _repo.clearHistory(userId);
    await _repo.updateUserSettings(userId, historyClearedAtMs: clearedAtMs);
    _history = [];
    notifyListeners();

    final uid = await _personalBoardCloudUid();
    if (uid == null || uid.isEmpty) return;
    await _notificationSync.syncLearnerSpeakHistory(
      learnerFirebaseUid: uid,
      history: const [],
    );
  }

  Future<void> _loadLinkedChildren({bool syncCloudInBackground = false}) async {
    if (_user == null || !_user!.isParent) {
      _linkedChildren = [];
      _selectedChildId = null;
      return;
    }
    if (syncCloudInBackground) {
      unawaited(() async {
        await _syncLinkedChildrenFromCloud();
        if (_user == null || !_user!.isParent) return;
        _linkedChildren = await _repo.getLinkedChildren(_user!.id);
        if (_linkedChildren.isEmpty) {
          _selectedChildId = null;
        } else if (_selectedChildId == null ||
            !_linkedChildren.any((c) => c.learnerId == _selectedChildId)) {
          _selectedChildId = _linkedChildren.first.learnerId;
        }
        _bumpLiveDataRevision();
      }());
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

    var authUid = FirebaseService.instance.currentUid;
    authUid ??= await FirebaseService.instance.waitForAuthUid(
      timeout: !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
          ? const Duration(seconds: 20)
          : const Duration(seconds: 8),
    );
    if (authUid == null || authUid.isEmpty) return null;

    final storedUid = _user!.firebaseUid?.trim();
    if (storedUid != null && storedUid.isNotEmpty && storedUid != authUid) {
      debugPrint(
        'Firebase UID mismatch (db=$storedUid, auth=$authUid); cloud sync skipped.',
      );
      return null;
    }

    if (storedUid == null || storedUid.isEmpty) {
      await _repo.linkFirebaseUid(_user!.id, authUid);
      _user = _user!.copyWith(firebaseUid: authUid);
    }
    return authUid;
  }

  /// Parent/teacher Firestore reads require an active Firebase Auth session.
  Future<bool> _ensureCloudAuthSession({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (_user == null) return false;

    final isWindows =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    final effectiveTimeout = isWindows
        ? timeout + const Duration(seconds: 8)
        : timeout;
    final deadline = DateTime.now().add(effectiveTimeout);
    while (true) {
      final uid = await _resolveAccountFirebaseUid();
      if (uid != null && uid.isNotEmpty) return true;
      if (!DateTime.now().isBefore(deadline)) break;
      await Future<void>.delayed(const Duration(milliseconds: 450));
    }
    if (!_loggedCloudAuthMissing) {
      _loggedCloudAuthMissing = true;
      debugPrint(
        'Cloud auth session missing for ${_user!.role}; '
        'sign in again to restore cloud sync.',
      );
    }
    return false;
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
      if (links.isNotEmpty) {
        final remoteUids = links
            .map((l) => l.learnerFirebaseUid.trim())
            .where((uid) => uid.isNotEmpty)
            .toSet();
        await _repo.pruneStaleParentChildLinks(
          parentUserId: _user!.id,
          remoteLearnerFirebaseUids: remoteUids,
        );
      }
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
        _bumpLiveDataRevision();
      },
    );
  }

  Future<void> _syncFirebaseSessionAfterRestore() async {
    if (_user == null || !FirebaseService.instance.isAvailable) return;
    final needsCloud =
        _user!.isTeacher || _user!.isParent || _user!.isOnlineAccount;
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
      _watchForLateFirebaseAuthRestore();
    }
  }

  /// Firebase Auth can restore a persisted session shortly after startup.
  void _watchForLateFirebaseAuthRestore() {
    if (_user == null || !_user!.isOnlineAccount) return;
    final firebaseAuth = FirebaseService.instance.auth;
    if (firebaseAuth == null || firebaseAuth.currentUser != null) return;

    _firebaseAuthRestoreSubscription?.cancel();
    _firebaseAuthRestoreSubscription = firebaseAuth.authStateChanges().listen((
      user,
    ) async {
      if (user == null || _user == null) return;
      await _firebaseAuthRestoreSubscription?.cancel();
      _firebaseAuthRestoreSubscription = null;

      final storedUid = _user!.firebaseUid?.trim();
      if (storedUid != null && storedUid.isNotEmpty && user.uid != storedUid) {
        debugPrint('Late Firebase auth UID mismatch; cloud sync skipped.');
        return;
      }

      if (storedUid == null || storedUid.isEmpty) {
        await _repo.linkFirebaseUid(_user!.id, user.uid);
        _user = _user!.copyWith(firebaseUid: user.uid);
      }

      debugPrint('Firebase auth restored; resuming cloud sync.');
      unawaited(_activateMonitoringSync());
    });
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
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  Future<void> markAllNotificationsRead() async {
    if (_user == null || !_user!.isParent) return;
    final remoteIds = await _repo.unreadNotificationRemoteIds(_user!.id);
    await _repo.markAllNotificationsRead(_user!.id);
    if (remoteIds.isNotEmpty) {
      unawaited(_notificationSync.markAllRemoteNotificationsRead(remoteIds));
    }
    _notifications = [for (final n in _notifications) n.copyWith(isRead: true)];
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

  Future<void> refreshLinkedChildren({
    bool cloudSyncInBackground = true,
  }) async {
    await _loadLinkedChildren(syncCloudInBackground: cloudSyncInBackground);
    if (!cloudSyncInBackground) {
      await Future.wait(
        _linkedChildren.map((c) => refreshChildMonitoringData(c.learnerId)),
      );
    }
    notifyListeners();
  }

  Future<void> refreshTeacherClasses({
    bool cloudSyncInBackground = true,
  }) async {
    if (_user == null || !_user!.isTeacher) {
      _teacherClasses = [];
      _teacherStudentCount = 0;
      _teacherClassStudentCounts.clear();
      notifyListeners();
      return;
    }
    await _loadTeacherClasses();
    await _loadPendingJoinRequests();
    await _refreshTeacherClassCounts();
    notifyListeners();

    if (cloudSyncInBackground) {
      unawaited(_syncTeacherClassesFromCloudAndReload());
      return;
    }

    await _syncTeacherClassesFromCloud();
    await _loadTeacherClasses();
    await _loadPendingJoinRequests();
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
    _teacherStudentCount = await _repo.countEnrolledStudentsForTeacher(
      _user!.id,
    );
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
    if (!await _ensureCloudAuthSession()) return;

    final teacherFirebaseUid = await _resolveAccountFirebaseUid();
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
          teacherName: _teacherNameForCloudSync(),
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

      // Push local edits first so a pull never overwrites unsynced lesson phrases.
      for (final teacherClass in localClasses) {
        await _pushClassContentToCloud(teacherClass.id);
        await _syncClassLessonsFromCloud(
          classId: teacherClass.id,
          classCode: teacherClass.code,
        );
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
    if (!await _ensureCloudAuthSession()) return;
    final teacherFirebaseUid = await _resolveAccountFirebaseUid();
    if (teacherFirebaseUid == null || teacherFirebaseUid.isEmpty) return;

    await _notificationSync.syncTeacherClass(
      classCode: classCode,
      className: className,
      teacherFirebaseUid: teacherFirebaseUid,
      teacherUserId: _user!.id,
      createdAt: DateTime.now(),
      teacherName: _teacherNameForCloudSync(),
    );
  }

  String _teacherNameForCloudSync() {
    final full = _user?.fullName.trim() ?? '';
    if (full.isNotEmpty && !AppRepository.isGenericAccountName(full)) {
      return full;
    }
    final fromSignup = _welcomeFirstName.trim();
    if (fromSignup.isNotEmpty) return fromSignup;
    return full;
  }

  Future<String> _resolveCloudTeacherDisplayName({
    RemoteTeacherClass? remoteClass,
    String? enrollmentTeacherName,
  }) async {
    for (final candidate in [remoteClass?.teacherName, enrollmentTeacherName]) {
      final trimmed = candidate?.trim() ?? '';
      if (trimmed.isNotEmpty && !AppRepository.isGenericAccountName(trimmed)) {
        return trimmed;
      }
    }

    final uid = remoteClass?.teacherFirebaseUid.trim() ?? '';
    if (uid.isEmpty || !_notificationSync.isCloudAvailable) return '';

    try {
      final profile = await _notificationSync
          .getUserProfileFromCloud(uid)
          .timeout(const Duration(seconds: 8));
      if (profile == null) return '';
      final resolved = AppRepository.resolveLoginFullName(
        profile: profile,
        existingName: null,
      );
      if (resolved.isNotEmpty &&
          !AppRepository.isGenericAccountName(resolved)) {
        return resolved;
      }
    } catch (e, st) {
      debugPrint('Resolve cloud teacher display name failed: $e\n$st');
    }
    return '';
  }

  Future<void> _applyCloudTeacherDisplayName({
    required int teacherUserId,
    RemoteTeacherClass? remoteClass,
    String? enrollmentTeacherName,
  }) async {
    final name = await _resolveCloudTeacherDisplayName(
      remoteClass: remoteClass,
      enrollmentTeacherName: enrollmentTeacherName,
    );
    if (name.isEmpty) return;
    await _repo.applyTeacherNameIfKnown(
      teacherUserId: teacherUserId,
      teacherName: name,
    );
  }

  Future<List<TeacherRecentAlert>> getTeacherRecentAlerts({
    int limit = 4,
  }) async {
    if (_user == null || !_user!.isTeacher) return [];
    await _syncTeacherAlertsFromCloud();
    return _repo.getRecentAlertsForTeacher(
      teacherUserId: _user!.id,
      limit: limit,
    );
  }

  Future<List<TeacherRecentAlert>> getTeacherAlertHistory({
    int limit = 100,
  }) async {
    if (_user == null || !_user!.isTeacher) return [];
    await _syncTeacherAlertsFromCloud();
    return _repo.getRecentAlertsForTeacher(
      teacherUserId: _user!.id,
      limit: limit,
    );
  }

  Future<List<TeacherRecentLesson>> getTeacherRecentLessons({
    int limit = 8,
  }) async {
    if (_user == null || !_user!.isTeacher) return [];
    return _repo.getRecentLessonsForTeacher(
      teacherUserId: _user!.id,
      limit: limit,
    );
  }

  Future<List<TeacherRecentLesson>> getTeacherLessonHistory({
    int limit = 100,
  }) async {
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
    await stopLiveClassContentSync(classId);
    await refreshTeacherClasses();
    unawaited(_reconcileClassContentLiveSync());
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
        await _publishClassContentChange(classId);
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
      final learnerFirebaseUid = await _repo.getFirebaseUidForUser(
        student.learnerId,
      );
      if (learnerFirebaseUid == null || learnerFirebaseUid.isEmpty) continue;
      await _notificationSync.syncClassEnrollment(
        classId: classId,
        classCode: classCode,
        className: className,
        teacherFirebaseUid: teacherFirebaseUid,
        learnerUserId: student.learnerId,
        learnerName: student.fullName,
        learnerFirebaseUid: learnerFirebaseUid,
        teacherName: _teacherNameForCloudSync(),
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
      _enqueueClassContentPush(classId);
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
      unawaited(
        _syncEnrolledClassLessonsFromCloudAndReload(classId, classCode),
      );
      return lessons;
    }
    await _syncClassLessonsFromCloud(classId: classId, classCode: classCode);
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
      await _syncClassLessonsFromCloud(classId: classId, classCode: classCode);
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
    await _pushClassContentToCloud(classId);
    return _repo.getClassLessons(teacherUserId: _user!.id, classId: classId);
  }

  Future<void> _syncTeacherClassLessonsFromCloudAndReload(
    int classId,
    String classCode,
  ) async {
    try {
      _enqueueClassContentPush(classId);
      if (_classLocalEditAt[classId] != null ||
          _classContentPushInFlight[classId] == true ||
          _classContentPushPending[classId] == true) {
        notifyListeners();
        return;
      }
      await _syncClassLessonsFromCloud(classId: classId, classCode: classCode);
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
        if (!_liveClassContentIds.contains(classId)) {
          unawaited(
            _syncClassLessonsFromCloud(classId: classId, classCode: classCode),
          );
        }
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
    _markClassLocallyEdited(classId);
    final lesson = await _repo.createClassLesson(
      teacherUserId: _user!.id,
      classId: classId,
      title: title.trim(),
    );
    if (lesson != null) {
      await _publishClassContentChange(classId);
    }
    return lesson;
  }

  Future<bool> updateClassLesson(int lessonId, String title) async {
    if (_user == null || !_user!.isTeacher) return false;
    final classId = await _repo.classIdForLesson(lessonId);
    if (classId != null) _markClassLocallyEdited(classId);
    final updated = await _repo.updateClassLesson(
      teacherUserId: _user!.id,
      lessonId: lessonId,
      title: title.trim(),
    );
    if (updated && classId != null) {
      await _publishClassContentChange(classId);
    }
    return updated;
  }

  Future<bool> deleteClassLesson(int lessonId) async {
    if (_user == null || !_user!.isTeacher) return false;
    final classId = await _repo.classIdForLesson(lessonId);
    if (classId != null) _markClassLocallyEdited(classId);
    final deleted = await _repo.deleteClassLesson(
      teacherUserId: _user!.id,
      lessonId: lessonId,
    );
    if (deleted && classId != null) {
      await _publishClassContentChange(classId);
    }
    return deleted;
  }

  Future<List<LessonPhrase>> getLessonPhrases(int lessonId) async {
    if (_user == null || !_user!.isTeacher) return [];
    return _repo.getLessonPhrases(teacherUserId: _user!.id, lessonId: lessonId);
  }

  Future<String?> addLessonPhrase(
    int lessonId,
    String text, {
    String? imagePath,
  }) async {
    if (_user == null || text.trim().isEmpty) return null;
    final classId = await _repo.classIdForLesson(lessonId);
    if (classId != null) _markClassLocallyEdited(classId);
    final saved = await persistPhraseImageIfNeeded(imagePath);
    final phrase = await _repo.addLessonPhrase(
      teacherUserId: _user!.id,
      lessonId: lessonId,
      text: text.trim(),
      imagePath: saved,
    );
    if (phrase != null && classId != null) {
      await _publishClassContentChange(classId);
    }
    return phrase == null ? AppStrings.unableAddPhrase(_language) : null;
  }

  Future<void> deleteLessonPhrase(int phraseId) async {
    if (_user == null || !_user!.isTeacher) return;
    final classId = await _repo.classIdForLessonPhrase(phraseId);
    final phraseKey = await _repo.cloudPhraseKeyForLessonPhrase(phraseId);
    if (classId != null) {
      _markClassLocallyEdited(classId);
      _markLessonPhraseDeleted(classId, phraseKey);
    }
    await _repo.deleteLessonPhrase(
      teacherUserId: _user!.id,
      phraseId: phraseId,
    );
    if (classId != null) {
      await _publishClassContentChange(classId);
    }
  }

  Future<bool> updateLessonPhrase(
    int phraseId, {
    required String text,
    String? imagePath,
    required bool clearImage,
  }) async {
    if (_user == null || !_user!.isTeacher) return false;
    final classId = await _repo.classIdForLessonPhrase(phraseId);
    if (classId != null) _markClassLocallyEdited(classId);
    final savedImage = clearImage
        ? null
        : await persistPhraseImageIfNeeded(imagePath);
    final updated = await _repo.updateLessonPhrase(
      teacherUserId: _user!.id,
      phraseId: phraseId,
      text: text,
      imagePath: savedImage,
    );
    if (updated && classId != null) {
      await _publishClassContentChange(classId);
    }
    return updated;
  }

  Future<bool> _pushClassContentToCloud(int classId) async {
    if (!CloudScope.syncMonitoring) return false;
    if (_user == null || !_user!.isTeacher) return false;
    await FirebaseService.instance.initialize();
    await _notificationSync.initialize();
    if (!_notificationSync.isCloudAvailable) return false;
    final classRow = await _repo.findClassById(classId);
    if (classRow == null) return false;
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
      return false;
    }
    try {
      final content = await _repo.buildRemoteClassContent(
        teacherUserId: _user!.id,
        classId: classId,
        classCode: classCode,
        className: className,
        teacherFirebaseUid: teacherFirebaseUid,
      );
      if (content == null) return false;
      // Never overwrite cloud lessons with an empty local copy.
      if (content.lessons.isEmpty) {
        final existing = await _notificationSync
            .getClassContentFromCloud(classCode)
            .timeout(const Duration(seconds: 3));
        if (existing != null && existing.lessons.isNotEmpty) return false;
      }
      final synced = await _notificationSync.syncClassContent(content);
      if (!synced) return false;
      _lastOwnClassPushUpdatedAt[classId] = content.updatedAt;
      _classLocalEditAt.remove(classId);
      return true;
    } catch (e, st) {
      debugPrint('Push class content to cloud failed: $e\n$st');
      return false;
    }
  }

  Future<void> _syncClassLessonsFromCloud({
    required int classId,
    required String classCode,
  }) async {
    if (!CloudScope.syncMonitoring) return;
    await FirebaseService.instance.initialize();
    await _notificationSync.initialize();
    if (!_notificationSync.isCloudAvailable) return;
    final normalized = AppRepository.normalizeClassCode(classCode);
    if (!AppRepository.isValidClassCodeFormat(normalized)) return;
    try {
      final remote = await _notificationSync
          .getClassContentFromCloud(normalized)
          .timeout(const Duration(seconds: 5));
      if (remote == null) {
        debugPrint('No cloud content for class $normalized');
        return;
      }
      if (remote.lessons.isEmpty) {
        debugPrint('Cloud class $normalized has no lessons yet');
        return;
      }
      await _applyRemoteClassContent(classId, remote);
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
        final learnerFirebaseUid = await _repo.getFirebaseUidForUser(
          student.learnerId,
        );
        if (learnerFirebaseUid == null || learnerFirebaseUid.isEmpty) continue;
        await _notificationSync.syncClassEnrollment(
          classId: student.classId,
          classCode: student.classCode,
          className: student.className,
          teacherFirebaseUid: teacherFirebaseUid,
          learnerUserId: student.learnerId,
          learnerName: student.fullName,
          learnerFirebaseUid: learnerFirebaseUid,
          teacherName: _teacherNameForCloudSync(),
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
    String? customMessage,
  }) async {
    if (_user == null || !_user!.isTeacher) {
      return TeacherAlertDeliveryResult(
        inAppError: AppStrings.notSignedIn(_language),
        sms: SmsAlertResult.empty,
      );
    }

    final trimmedCustom = customMessage?.trim();
    final isCustom = trimmedCustom != null && trimmedCustom.isNotEmpty;
    final teacherName = _user!.fullName;

    final title = isCustom
        ? AppStrings.teacherCustomAlertTitle(
            _language,
            teacherName,
            learnerName,
          )
        : AppStrings.teacherAlertTitle(
            _language,
            teacherName,
            learnerName,
            alertType,
          );
    final body = isCustom
        ? AppStrings.teacherCustomAlertBody(
            _language,
            teacherName,
            trimmedCustom,
          )
        : AppStrings.teacherAlertBody(
            _language,
            teacherName,
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
      TeacherAlertStatus.noLinkedParents => AppStrings.alertNoLinkedParents(
        _language,
        learnerName,
      ),
      TeacherAlertStatus.notAuthorized => AppStrings.alertNotAuthorized(
        _language,
      ),
    };

    if (result.notificationIds.isNotEmpty) {
      _teacherAlertsRevision++;
      notifyListeners();
    }

    final learnerFirebaseUid = await _resolveLearnerFirebaseUid(learnerUserId);
    final localContacts = await _repo.getEmergencyContactsForLearner(
      learnerUserId,
    );
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
    final smsText = isCustom
        ? AppStrings.teacherCustomAlertSms(
            teacherName,
            learnerName,
            trimmedCustom,
          )
        : AppStrings.teacherAlertSms(
            _language,
            teacherName,
            learnerName,
            alertType,
          );

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
      inAppError:
          inAppError ??
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
    await _refreshEnrolledClassTeacherNamesFromCloud();
    _enrolledClasses = await _repo.getEnrolledClasses(_user!.id);
  }

  Future<void> _refreshEnrolledClassTeacherNamesFromCloud() async {
    if (_user == null || !_user!.isLearner) return;
    if (!CloudScope.syncMonitoring || !_notificationSync.isCloudAvailable) {
      return;
    }
    if (await NetworkStatus.isOffline()) return;

    final classes = await _repo.getEnrolledClasses(_user!.id);
    for (final enrolled in classes) {
      final code = AppRepository.normalizeClassCode(enrolled.classCode);
      if (!AppRepository.isValidClassCodeFormat(code)) continue;
      try {
        final remote = await _notificationSync
            .getTeacherClassByCodeFromCloud(code)
            .timeout(const Duration(seconds: 8));
        await _applyCloudTeacherDisplayName(
          teacherUserId: enrolled.teacherId,
          remoteClass: remote,
        );
      } catch (e, st) {
        debugPrint('Refresh enrolled class teacher name failed: $e\n$st');
      }
    }
  }

  /// Pulls cloud enrollment records for this learner and imports any missing
  /// teacher-class records into local SQLite so the learner sees them.
  Future<void> _syncEnrolledClassesFromCloud() async {
    if (!CloudScope.syncMonitoring) return;
    if (_user == null ||
        !_user!.isLearner ||
        !_notificationSync.isCloudAvailable) {
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
      RemoteTeacherClass? remoteClass;
      if (classRow == null) {
        remoteClass = await _notificationSync
            .getTeacherClassByCodeFromCloud(code)
            .timeout(const Duration(seconds: 8));
        if (remoteClass != null) {
          classRow = await _repo.importRemoteTeacherClassForEnrollment(
            remoteClass,
          );
        }
      }
      if (classRow == null) continue;

      final teacherId = classRow['teacher_user_id'] as int?;
      if (teacherId != null) {
        try {
          remoteClass ??= await _notificationSync
              .getTeacherClassByCodeFromCloud(code)
              .timeout(const Duration(seconds: 8));
          await _applyCloudTeacherDisplayName(
            teacherUserId: teacherId,
            remoteClass: remoteClass,
            enrollmentTeacherName: enrollment.teacherName,
          );
        } catch (e, st) {
          debugPrint('Apply cloud teacher name failed: $e\n$st');
        }
      }

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

    if (remoteClassCodes.isNotEmpty) {
      await _repo.pruneStaleEnrollmentsForLearner(
        learnerUserId: learnerUserId,
        remoteClassCodes: remoteClassCodes,
      );
    }
    await _pruneEnrollmentsForDeletedCloudClasses(learnerUserId);
  }

  /// Drops local enrollments when the teacher removed the class from cloud.
  Future<void> _pruneEnrollmentsForDeletedCloudClasses(
    int learnerUserId,
  ) async {
    if (!CloudScope.syncMonitoring || !_notificationSync.isCloudAvailable) {
      return;
    }
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
    if (_user == null ||
        !_user!.isLearner ||
        !_notificationSync.isCloudAvailable) {
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

      final teacherFirebaseUid =
          remoteClass.teacherFirebaseUid.trim().isNotEmpty
          ? remoteClass.teacherFirebaseUid.trim()
          : await _repo.getFirebaseUidForUser(enrolled.teacherId);
      if (teacherFirebaseUid == null || teacherFirebaseUid.isEmpty) continue;
      final teacherName = await _repo.teacherDisplayNameForUserId(
        enrolled.teacherId,
      );
      await _notificationSync.syncClassEnrollment(
        classId: enrolled.classId,
        classCode: code,
        className: enrolled.className,
        teacherFirebaseUid: teacherFirebaseUid,
        learnerUserId: _user!.id,
        learnerName: _user!.fullName,
        learnerFirebaseUid: learnerFirebaseUid,
        teacherName: AppRepository.isGenericAccountName(teacherName)
            ? null
            : teacherName,
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
    RemoteTeacherClass? remoteClass;
    if (classRow == null) {
      if (!_notificationSync.isCloudAvailable) {
        return AppStrings.classNotFound(_language);
      }
      try {
        remoteClass = await _notificationSync
            .getTeacherClassByCodeFromCloud(normalized)
            .timeout(const Duration(seconds: 12));
        if (remoteClass != null) {
          teacherFirebaseUidFromRemote = remoteClass.teacherFirebaseUid;
          classRow = await _repo.importRemoteTeacherClassForEnrollment(
            remoteClass,
          );
        }
      } catch (e, st) {
        debugPrint('Cloud class code lookup failed: $e\n$st');
      }
      if (classRow == null) {
        return AppStrings.classNotFound(_language);
      }
    }
    if (_notificationSync.isCloudAvailable) {
      try {
        remoteClass ??= await _notificationSync
            .getTeacherClassByCodeFromCloud(normalized)
            .timeout(const Duration(seconds: 12));
        if (remoteClass != null) {
          teacherFirebaseUidFromRemote ??= remoteClass.teacherFirebaseUid;
          final teacherId = classRow['teacher_user_id'] as int?;
          if (teacherId != null) {
            await _applyCloudTeacherDisplayName(
              teacherUserId: teacherId,
              remoteClass: remoteClass,
            );
          }
        }
      } catch (e, st) {
        debugPrint('Cloud class teacher name refresh failed: $e\n$st');
      }
    }
    final classId = classRow['id'] as int;
    if (await _repo.isLearnerEnrolled(_user!.id, classId)) {
      return AppStrings.classAlreadyEnrolled(_language);
    }
    final existingRequest = await _repo.findJoinRequest(
      learnerUserId: _user!.id,
      classId: classId,
    );
    if (existingRequest != null && existingRequest.isPending) {
      return AppStrings.joinRequestAlreadyPending(_language);
    }
    final learnerFirebaseUid =
        _user!.firebaseUid ?? FirebaseService.instance.currentUid;
    final teacherUserId = classRow['teacher_user_id'] as int?;
    final teacherFirebaseUid =
        teacherFirebaseUidFromRemote ??
        (teacherUserId == null
            ? null
            : await _repo.getFirebaseUidForUser(teacherUserId));
    if (learnerFirebaseUid == null ||
        learnerFirebaseUid.isEmpty ||
        teacherFirebaseUid == null ||
        teacherFirebaseUid.isEmpty ||
        teacherUserId == null) {
      return AppStrings.signInOnlineToJoinClass(_language);
    }
    if (!_notificationSync.isCloudAvailable) {
      return AppStrings.signInOnlineToJoinClass(_language);
    }
    final now = DateTime.now();
    final className = (classRow['class_name'] as String?) ?? '';
    await _repo.upsertJoinRequest(
      learnerUserId: _user!.id,
      classId: classId,
      classCode: normalized,
      className: className,
      teacherUserId: teacherUserId,
      learnerName: _user!.fullName,
      status: ClassJoinRequestStatus.pending,
      requestedAt: now,
      learnerFirebaseUid: learnerFirebaseUid,
      teacherFirebaseUid: teacherFirebaseUid,
      remoteId: '${normalized}_$learnerFirebaseUid',
    );
    await _notificationSync.syncClassJoinRequest(
      event: ClassJoinRequestCloudEvent(
        classId: classId,
        classCode: normalized,
        className: className,
        teacherFirebaseUid: teacherFirebaseUid,
        teacherUserId: teacherUserId,
        learnerUserId: _user!.id,
        learnerName: _user!.fullName,
        learnerFirebaseUid: learnerFirebaseUid,
        status: ClassJoinRequest.statusToString(ClassJoinRequestStatus.pending),
        requestedAt: now,
      ),
    );
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
    await _reconcileClassContentLiveSync();
    notifyListeners();
  }

  Future<void> _syncEnrolledClassesFromCloudAndReload() async {
    try {
      await _syncEnrolledClassesFromCloud();
      await _loadEnrolledClasses();
      await _reconcileClassContentLiveSync();
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
    await stopLiveClassContentSync(classId);
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
    if (_user == null || !_notificationSync.isCloudAvailable) return;
    if (!_hasPersonalBoardRole()) return;
    final uid = await _personalBoardCloudUid();
    if (uid == null || uid.isEmpty) return;
    final remote = await _notificationSync.getLearnerCategoriesFromCloud(uid);
    if (remote.isNotEmpty) {
      await _repo.mergeRemoteLearnerCategories(
        learnerUserId: _user!.id,
        remoteCategories: remote,
      );
    }
    final local = (await _repo.getCategories(_user!.id))
        .map(
          (c) => RemoteLearnerCategory(
            key: c.key,
            name: c.name,
            iconKey: c.iconKey,
          ),
        )
        .toList();
    final merged = AppRepository.mergeCategoriesForCloudExport(
      local: local,
      remote: remote,
    );
    if (merged.isEmpty) return;
    await _notificationSync.syncLearnerCategories(
      learnerFirebaseUid: uid,
      categories: merged,
    );
  }

  Future<void> restorePhrase(
    PhraseModel phrase, {
    bool restoreFavorite = false,
  }) async {
    if (_user == null || phrase.isBuiltin) return;
    final restored = await _repo.addPhrase(
      userId: _user!.id,
      text: phrase.text,
      categoryKey: phrase.categoryKey,
      imagePath: phrase.imagePath,
    );
    if (restoreFavorite) {
      await _repo.addFavorite(
        userId: _user!.id,
        phraseText: restored.text,
        categoryKey: restored.categoryKey,
        phraseId: restored.id,
        imagePath: restored.imagePath,
      );
    }
    await _refreshPersonalBoard();
    notifyListeners();
    await _pushLearnerCustomPhrasesToCloud();
    if (restoreFavorite) await _pushLearnerFavoritesToCloud();
  }

  Future<void> _pushLearnerCategoriesToCloud() async {
    if (!CloudScope.syncMonitoring) return;
    if (_user == null || !_notificationSync.isCloudAvailable) return;
    if (!_hasPersonalBoardRole()) return;
    final uid = await _personalBoardCloudUid();
    if (uid == null || uid.isEmpty) return;
    final local = (await _repo.getCategories(_user!.id))
        .map(
          (category) => RemoteLearnerCategory(
            key: category.key,
            name: category.name,
            iconKey: category.iconKey,
          ),
        )
        .toList();
    await _notificationSync.syncLearnerCategories(
      learnerFirebaseUid: uid,
      categories: local,
    );
  }

  Future<void> _pushLearnerCustomPhrasesToCloud() async {
    if (!CloudScope.syncMonitoring) return;
    if (_user == null || !_notificationSync.isCloudAvailable) return;
    if (!_hasPersonalBoardRole()) return;
    final uid = await _personalBoardCloudUid();
    if (uid == null || uid.isEmpty) return;
    final local = await _repo.getCustomPhrasesForCloudSync(
      _user!.id,
      firebaseUid: uid,
    );
    await _notificationSync.syncLearnerCustomPhrases(
      learnerFirebaseUid: uid,
      phrases: local,
    );
  }

  Future<void> _pushLearnerFavoritesToCloud() async {
    if (!CloudScope.syncMonitoring) return;
    if (_user == null || !_hasPersonalBoardRole()) return;
    final uid = await _personalBoardCloudUid();
    if (uid == null || uid.isEmpty) return;
    final local = await _repo.getFavoritesForCloudSync(
      _user!.id,
      firebaseUid: uid,
    );
    await _notificationSync.syncLearnerFavorites(
      learnerFirebaseUid: uid,
      favorites: local,
    );
  }

  Future<void> _syncLearnerCustomPhrasesToCloud() async {
    if (!CloudScope.syncMonitoring) return;
    if (_user == null || !_notificationSync.isCloudAvailable) return;
    if (!_hasPersonalBoardRole()) return;
    final uid = await _personalBoardCloudUid();
    if (uid == null || uid.isEmpty) return;
    final remote = await _notificationSync.getLearnerCustomPhrasesFromCloud(
      uid,
    );
    if (remote.isNotEmpty) {
      await _repo.mergeRemoteLearnerCustomPhrases(
        learnerUserId: _user!.id,
        phrases: remote,
      );
      await _repo.dedupeCustomPhrases(_user!.id);
    }
    final local = await _repo.getCustomPhrasesForCloudSync(
      _user!.id,
      firebaseUid: uid,
    );
    await _notificationSync.syncLearnerCustomPhrases(
      learnerFirebaseUid: uid,
      phrases: local,
    );
  }

  Future<void> _syncLearnerFavoritesToCloud() async {
    if (!CloudScope.syncMonitoring) return;
    if (_user == null || !_hasPersonalBoardRole()) return;
    // Push local favorites as source of truth. Pull-before-push was wiping
    // stars/unstars that had not reached the cloud yet.
    await _favoriteCloudMutation;
    await _pushLearnerFavoritesToCloud();
  }

  Future<void> _syncLearnerSpeakHistoryToCloud() async {
    if (!CloudScope.syncMonitoring) return;
    if (_user == null || !_notificationSync.isCloudAvailable) return;
    if (!_hasPersonalBoardRole()) return;
    final uid = await _personalBoardCloudUid();
    if (uid == null || uid.isEmpty) return;
    final settings = await _repo.getUserSettings(_user!.id);
    final clearedAtMs = settings['history_cleared_at_ms'] as int?;
    final remote = await _notificationSync.getLearnerSpeakHistoryFromCloud(uid);
    final retainedRemote = clearedAtMs == null
        ? remote
        : remote
              .where(
                (item) => item.createdAt.millisecondsSinceEpoch > clearedAtMs,
              )
              .toList();
    if (retainedRemote.isNotEmpty) {
      await _repo.mergeRemoteLearnerSpeakHistory(
        learnerUserId: _user!.id,
        history: retainedRemote,
      );
    }
    final local = await _repo.getHistoryForCloudSync(_user!.id);
    final merged = AppRepository.mergeSpeakHistoryForCloudExport(
      local: local,
      remote: retainedRemote,
    );
    await _notificationSync.syncLearnerSpeakHistory(
      learnerFirebaseUid: uid,
      history: merged,
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
    final learnerFirebaseUid = learnerUserId == _user?.id
        ? (await _resolveAccountFirebaseUid() ??
              await _resolveLearnerFirebaseUid(learnerUserId))
        : await _resolveLearnerFirebaseUid(learnerUserId);
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

  Future<void> _pullLearnerFavoritesFromCloud(int learnerUserId) async {
    if (!CloudScope.syncMonitoring) return;
    if (await NetworkStatus.isOffline()) return;
    // Don't let a stale cloud list undo a star/unstar the user just made.
    if (learnerUserId == _user?.id && _favoriteMergeGraceActive) return;
    await FirebaseService.instance.initialize();
    await _notificationSync.initialize();
    if (!_notificationSync.isCloudAvailable) return;
    if (_user != null && (_user!.isParent || _user!.isTeacher)) {
      if (!await _ensureCloudAuthSession()) return;
    }
    final learnerFirebaseUid = learnerUserId == _user?.id
        ? (await _resolveAccountFirebaseUid() ??
              await _resolveLearnerFirebaseUid(learnerUserId))
        : await _resolveLearnerFirebaseUid(learnerUserId);
    if (learnerFirebaseUid == null || learnerFirebaseUid.isEmpty) return;
    try {
      final favorites = await _notificationSync
          .getLearnerFavoritesFromCloud(learnerFirebaseUid)
          .timeout(const Duration(seconds: 15));
      await _repo.mergeRemoteLearnerFavorites(
        learnerUserId: learnerUserId,
        favorites: favorites,
        skipRemoteKeys: learnerUserId == _user?.id
            ? Set<String>.from(_locallyRemovedFavoriteKeys)
            : const {},
      );
    } catch (e, st) {
      debugPrint('Pull learner favorites failed: $e\n$st');
    }
  }

  Future<void> _pullLearnerSpeakHistoryFromCloud(int learnerUserId) async {
    if (!CloudScope.syncMonitoring) return;
    if (await NetworkStatus.isOffline()) return;
    await FirebaseService.instance.initialize();
    await _notificationSync.initialize();
    if (!_notificationSync.isCloudAvailable) return;
    if (_user != null && (_user!.isParent || _user!.isTeacher)) {
      if (!await _ensureCloudAuthSession()) return;
    }
    final learnerFirebaseUid = learnerUserId == _user?.id
        ? (await _resolveAccountFirebaseUid() ??
              await _resolveLearnerFirebaseUid(learnerUserId))
        : await _resolveLearnerFirebaseUid(learnerUserId);
    if (learnerFirebaseUid == null || learnerFirebaseUid.isEmpty) return;
    try {
      final history = await _notificationSync
          .getLearnerSpeakHistoryFromCloud(learnerFirebaseUid)
          .timeout(const Duration(seconds: 15));
      var retainedHistory = history;
      if (learnerUserId == _user?.id) {
        final settings = await _repo.getUserSettings(learnerUserId);
        final clearedAtMs = settings['history_cleared_at_ms'] as int?;
        if (clearedAtMs != null) {
          retainedHistory = history
              .where(
                (item) => item.createdAt.millisecondsSinceEpoch > clearedAtMs,
              )
              .toList();
        }
      }
      final inserted = await _repo.mergeRemoteLearnerSpeakHistory(
        learnerUserId: learnerUserId,
        history: retainedHistory,
      );
      if (inserted > 0) {
        _bumpChildMonitoringRevision(learnerUserId);
      }
      debugPrint(
        'Pulled ${retainedHistory.length} speak history entries for user $learnerUserId'
        ' ($inserted new)',
      );
    } catch (e, st) {
      debugPrint('Pull learner speak history failed: $e\n$st');
    }
  }

  /// All learner categories (default + custom) from local store after board sync.
  Future<List<CategoryModel>> getCategoriesForMonitoring(
    int learnerUserId,
  ) async {
    var categories = await _repo.getCategories(learnerUserId);
    if (categories.isEmpty) {
      await _repo.seedLearnerData(learnerUserId);
      categories = await _repo.getCategories(learnerUserId);
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

  Future<String?> _resolveLearnerFirebaseUid(
    int learnerUserId, {
    bool forMonitoring = false,
  }) async {
    final fromUser = await _repo.getFirebaseUidForUser(learnerUserId);
    if (fromUser != null && fromUser.isNotEmpty) return fromUser;

    if (!CloudScope.syncMonitoring) return null;

    if (forMonitoring &&
        _user != null &&
        (_user!.isParent || _user!.isTeacher)) {
      final fromCloud = await _resolveLearnerFirebaseUidFromCloud(
        learnerUserId,
      );
      if (fromCloud != null && fromCloud.isNotEmpty) return fromCloud;
      return null;
    }

    return _resolveLearnerFirebaseUidFromCloud(learnerUserId);
  }

  Future<String?> _resolveLearnerFirebaseUidFromCloud(int learnerUserId) async {
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
  Future<void> refreshChildMonitoringData(
    int learnerUserId, {
    bool full = true,
  }) async {
    if (_user == null) return;
    await FirebaseService.instance.initialize();
    await _notificationSync.initialize();
    var cloudReady = true;
    if (_user!.isParent || _user!.isTeacher) {
      cloudReady = await _ensureCloudAuthSession();
    }
    final online =
        cloudReady &&
        !await NetworkStatus.isOffline() &&
        !NetworkStatus.isCloudBlocked &&
        _notificationSync.isCloudAvailable;
    if (online) {
      if (_user!.isTeacher) {
        await _syncTeacherClassesFromCloud();
      } else if (_user!.isParent) {
        await _loadLinkedChildren(syncCloudInBackground: false);
      }
    }
    final learnerUid = await _resolveLearnerFirebaseUid(
      learnerUserId,
      forMonitoring: true,
    );
    if (online && learnerUid != null && learnerUid.isNotEmpty) {
      if (full) {
        await _syncLearnerEnrollmentsFromCloudForUser(learnerUserId);
      }
      await _syncLearnerMonitoringBoardFromCloud(learnerUserId, full: full);
      if (_liveMonitoredLearnerIds.contains(learnerUserId)) {
        await startLiveChildMonitoringSync(learnerUserId);
      }
    } else if (online) {
      debugPrint(
        'Monitoring refresh skipped: no learner Firebase UID for user $learnerUserId',
      );
    }
    if (full) {
      _bumpChildMonitoringRevision(learnerUserId);
    }
  }

  Future<List<PhraseUsageStat>> getChildPhraseStats({
    required int learnerUserId,
    required ChildUsagePeriod period,
    DateTime? month,
    bool syncCloud = true,
  }) async {
    final range = _dateRangeForPeriod(period, month: month);

    List<RemoteLearnerActivity> cloudActivities = const [];
    if (syncCloud) {
      cloudActivities = await _fetchLearnerActivitiesForMonitoring(
        learnerUserId,
        full: false,
        rangeStart: range.$1,
      );
      if (cloudActivities.isNotEmpty) {
        await _repo.mergeRemoteLearnerActivities(
          learnerUserId: learnerUserId,
          activities: cloudActivities,
        );
      }
    }

    final localStats = await _repo.getPhraseUsageStats(
      learnerUserId: learnerUserId,
      rangeStart: range.$1,
      rangeEnd: range.$2,
    );
    if (!syncCloud || cloudActivities.isEmpty) {
      return localStats;
    }

    final cloudStats = AppRepository.aggregatePhraseUsageStatsFromActivities(
      activities: cloudActivities,
      rangeStart: range.$1,
      rangeEnd: range.$2,
    );
    return AppRepository.mergePhraseUsageStats(localStats, cloudStats);
  }

  Future<VocabularyGrowthPanelData> getChildVocabularyGrowth({
    required int learnerUserId,
    required ChildUsagePeriod period,
    DateTime? month,
    DateTime? linkedAt,
    bool syncCloud = false,
  }) async {
    final linked = linkedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final range = _dateRangeForPeriod(period, month: month);
    final locale = _language == AppLanguage.filipino ? 'fil_PH' : 'en_US';
    final earliest = linked.isAfter(range.$1) ? linked : range.$1;

    List<RemoteLearnerActivity> cloudActivities = const [];
    if (syncCloud) {
      cloudActivities = await _fetchLearnerActivitiesForMonitoring(
        learnerUserId,
        full: false,
        rangeStart: range.$1,
      );
      if (cloudActivities.isNotEmpty) {
        await _repo.mergeRemoteLearnerActivities(
          learnerUserId: learnerUserId,
          activities: cloudActivities,
        );
      }
    }

    final localStats = await _repo.getPhraseUsageStats(
      learnerUserId: learnerUserId,
      rangeStart: range.$1,
      rangeEnd: range.$2,
    );
    final cloudStats = cloudActivities.isEmpty
        ? const <PhraseUsageStat>[]
        : AppRepository.aggregatePhraseUsageStatsFromActivities(
            activities: cloudActivities,
            rangeStart: range.$1,
            rangeEnd: range.$2,
          );
    final usageStats = AppRepository.mergePhraseUsageStats(
      localStats,
      cloudStats,
    );
    final phrasesUsed = usageStats.length;
    final phraseTaps = usageStats.fold<int>(0, (sum, stat) => sum + stat.count);

    final firstUsesFromCustom = await _repo.getCustomPhraseAdditions(
      learnerUserId: learnerUserId,
    );
    final firstUses = firstUsesFromCustom.isNotEmpty
        ? firstUsesFromCustom
        : await _repo.getPhraseFirstUses(learnerUserId: learnerUserId);
    final periodFirstUses = firstUses
        .where(
          (entry) =>
              !entry.firstUsedAt.isBefore(range.$1) &&
              entry.firstUsedAt.isBefore(range.$2),
        )
        .toList();

    final trendSummary = VocabularyGrowthCalculator.summarize(
      firstUses: firstUses,
      now: DateTime.now(),
      rangeStart: earliest,
      localeName: locale,
    );

    final summary = VocabularyGrowthSummary(
      totalVocabulary: periodFirstUses.isNotEmpty
          ? periodFirstUses.length
          : phrasesUsed,
      newWordsThisWeek: trendSummary.newWordsThisWeek,
      newWordsThisMonth: trendSummary.newWordsThisMonth,
      weeklyTrend: trendSummary.weeklyTrend,
      monthlyTrend: trendSummary.monthlyTrend,
      categorySlices: trendSummary.categorySlices,
    );

    return VocabularyGrowthPanelData(
      summary: summary,
      phrasesUsed: phrasesUsed,
      phraseTaps: phraseTaps,
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

  Future<void> _syncLearnerEnrollmentsFromCloudForUser(
    int learnerUserId,
  ) async {
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
      await _syncClassLessonsFromCloud(classId: classId, classCode: classCode);
    }
    return _repo.getClassLessonsByClassId(classId);
  }

  Future<ChildLessonProgressEntry> getLessonProgressForMonitoring({
    required int learnerUserId,
    required String className,
    required String lessonTitle,
    required ChildUsagePeriod period,
    DateTime? month,
    int? lessonId,
  }) async {
    final range = _dateRangeForPeriod(period, month: month);
    return _repo.getLessonProgressForLesson(
      learnerUserId: learnerUserId,
      className: className,
      lessonTitle: lessonTitle,
      lessonId: lessonId,
      rangeStart: range.$1,
      rangeEnd: range.$2,
    );
  }

  Future<ChildSessionSummary> getChildSessionSummary({
    required int learnerUserId,
    required ChildUsagePeriod period,
    DateTime? month,
    bool syncCloud = false,
  }) async {
    final range = _dateRangeForPeriod(period, month: month);
    final allEvents = await _repo.getHistoryTimestamps(
      learnerUserId: learnerUserId,
      rangeStart: range.$1,
      rangeEnd: range.$2,
      personalOnly: true,
    );
    final locale = _language == AppLanguage.filipino ? 'fil_PH' : 'en_US';
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
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: weekday - 1));
        return (start, start.add(const Duration(days: 7)));
      case ChildUsagePeriod.month:
        final m = month ?? DateTime(now.year, now.month);
        final start = DateTime(m.year, m.month);
        final end = DateTime(m.year, m.month + 1);
        return (start, end);
    }
  }

  String get profileCode => (_user?.isLearner ?? false) ? _profileCode : '';

  Future<String?> updateProfileName({
    required String firstName,
    required String lastName,
  }) async {
    if (_user == null) return AppStrings.notSignedIn(_language);
    final first = firstName.trim();
    final last = lastName.trim();
    final full = '$first $last'.trim();
    if (full.isEmpty) return AppStrings.fillAllFields(_language);
    await _repo.updateUserFullName(_user!.id, full);
    await _repo.updateUserSettings(
      _user!.id,
      firstName: first,
      lastName: last,
    );
    _user = _user!.copyWith(fullName: full);
    _welcomeFirstName = first;
    _profileLastName = last;
    _hasStoredLastName = true;
    notifyListeners();
    await _enqueueProfileCloudSync();
    return null;
  }

  Future<String?> updateEmergencyContacts(List<String> contacts) async {
    if (_user == null) return AppStrings.notSignedIn(_language);
    final cleaned = AppRepository.normalizeEmergencyContacts(contacts);
    await _repo.updateEmergencyContacts(_user!.id, cleaned);
    _emergencyContacts = cleaned;
    notifyListeners();
    await _enqueueProfileCloudSync();
    return null;
  }

  Future<String?> updateProfileExtras({
    required String address,
    int? age,
    required String gradeLevel,
    String birthdate = '',
  }) async {
    if (_user == null) return AppStrings.notSignedIn(_language);
    final trimmedBirth = birthdate.trim();
    await _repo.updateUserSettings(
      _user!.id,
      address: address,
      age: age,
      clearAge: age == null,
      gradeLevel: gradeLevel,
      birthdate: trimmedBirth,
      clearBirthdate: trimmedBirth.isEmpty,
    );
    _address = address.trim();
    _age = age;
    _gradeLevel = gradeLevel.trim();
    _birthdate = trimmedBirth;
    notifyListeners();
    await _enqueueProfileCloudSync();
    return null;
  }

  Future<String?> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (_user == null) return AppStrings.notSignedIn(_language);
    if (currentPassword.isEmpty || newPassword.isEmpty) {
      return AppStrings.fillAllFields(_language);
    }
    if (!AuthValidation.isStrongPassword(newPassword)) {
      return AppStrings.passwordTooShort(_language);
    }
    final ok = await _repo.updateUserPassword(
      _user!.id,
      currentPassword,
      newPassword,
    );
    if (!ok) return AppStrings.wrongCurrentPassword(_language);
    _user = _user!.copyWith(
      passwordHash: AppRepository.hashPassword(newPassword),
    );
    notifyListeners();
    return null;
  }

  Future<bool> speakText(
    String text, {
    bool record = false,
    String? categoryKey,
    String? className,
    String? lessonTitle,
    int? phraseId,
  }) async {
    final catKey = categoryKey ?? _selectedCategoryKey;
    final spoken = text.trim();
    if (spoken.isEmpty) {
      _currentSpeakGeneration = null;
      _resetSpeechTracking();
      notifyListeners();
      return false;
    }

    await SttService.releaseForTts();

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
    _readAlongWordIndex = 0;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      if (_isSpeaking) await tts.stop();
    } else {
      await tts.stop();
    }
    _currentSpeakGeneration = gen;

    _speakingText = spoken;
    _speakingPhraseId = phraseId;
    _isSpeaking = true;
    _spokenWordStart = -1;
    _spokenWordEnd = -1;
    notifyListeners();

    final completed = await _speakUntilDone(gen: gen, fullText: spoken);
    if (gen != _ttsGeneration) {
      if (_speechPaused) return true;
      return false;
    }
    if (!completed) {
      if (_speechPaused) return true;
      _currentSpeakGeneration = null;
      _resetSpeechTracking();
      notifyListeners();
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
    notifyListeners();

    final completed = await _speakUntilDone(gen: gen, fullText: fullText);
    if (gen != _ttsGeneration) {
      if (_speechPaused) return true;
      return false;
    }
    if (!completed) {
      if (_speechPaused) return true;
      _currentSpeakGeneration = null;
      _resetSpeechTracking();
      notifyListeners();
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
