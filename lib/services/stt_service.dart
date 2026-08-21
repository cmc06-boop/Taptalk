import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../core/l10n/app_strings.dart';

typedef SttResultHandler = void Function(String recognizedWords, bool isFinal);
typedef SttStatusHandler = void Function(String status);

/// Speech recognition for the For Me composer.
///
/// Keeps one user session alive across Android's short listen windows and
/// appends each spoken burst so the composer stays in sync with speech.
class SttService {
  SttService() {
    _active = this;
  }

  static SttService? _active;
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _ready = false;
  bool _sessionActive = false;
  bool _engineStarting = false;
  int _sessionId = 0;
  int _restartCount = 0;

  String? _localeId;
  SttResultHandler? _onResult;
  SttStatusHandler? _onStatus;
  void Function(SpeechRecognitionError error)? _onError;

  String _committed = '';
  String _current = '';
  String _lastEmitted = '';
  bool _heardSpeech = false;

  Timer? _silenceEndTimer;
  Timer? _restartTimer;
  DateTime? _ignoreEngineEventsUntil;

  static const Duration _silencePause = Duration(seconds: 7);
  static const Duration _restartDelay = Duration(milliseconds: 500);
  static const int _maxNetworkRetries = 6;
  static const double _speechRmsThreshold = 2;

  bool get isListening => _sessionActive;
  bool get isReady => _ready;

  /// Drops the mic so Android TTS can use the speaker. SpeechRecognizer
  /// keeps audio focus after listen and silently blocks phrase playback.
  static Future<void> releaseForTts() async {
    final service = _active;
    if (service == null || !service._ready) return;
    final wasListening =
        service._sessionActive || service._speech.isListening;
    await service.cancel();
    if (wasListening) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  Future<bool> initialize({
    SttStatusHandler? onStatus,
    void Function(SpeechRecognitionError error)? onError,
  }) async {
    _onStatus = onStatus;
    _onError = onError;

    final mic = await Permission.microphone.request();
    debugPrint('STT microphone permission: $mic');
    if (!mic.isGranted) return false;

    if (_ready) return true;

    _ready = await _speech.initialize(
      debugLogging: true,
      options: [
        stt.SpeechToText.androidNoBluetooth,
        stt.SpeechToText.androidIntentLookup,
      ],
      onStatus: _handleStatus,
      onError: _handleError,
    );
    debugPrint('STT initialize ready=$_ready');
    return _ready;
  }

  Future<String?> resolveLocale(AppLanguage lang) async {
    final locales = await _speech.locales();
    debugPrint(
      'STT locales (${locales.length}) appLang=$lang: '
      '${locales.map((l) => l.localeId).join(', ')}',
    );

    // Only use locales the device actually reports. Forcing fil_PH/tl_PH on
    // this phone returns error_language_not_supported and kills recognition.
    final preferred = lang == AppLanguage.filipino
        ? ['fil_PH', 'tl_PH', 'fil', 'tl', 'en_PH', 'en_US', 'en_SG', 'en_GB', 'en']
        : ['en_PH', 'en_US', 'en_SG', 'en_GB', 'en', 'fil_PH', 'tl_PH', 'fil', 'tl'];

    for (final want in preferred) {
      for (final available in locales) {
        if (_localeMatches(available.localeId, want)) {
          debugPrint('STT using locale ${available.localeId}');
          return available.localeId;
        }
      }
    }

    for (final available in locales) {
      final id = available.localeId.toLowerCase();
      if (id.startsWith('en')) {
        debugPrint('STT using locale ${available.localeId}');
        return available.localeId;
      }
    }

    debugPrint('STT using device default locale');
    return null;
  }

  Future<bool> startListening({
    required String? localeId,
    required SttResultHandler onResult,
  }) async {
    if (!_ready) {
      debugPrint('STT startListening skipped: not ready');
      return false;
    }

    if (_sessionActive) {
      await stop();
    } else {
      _clearTimers();
    }

    _onResult = onResult;
    _localeId = localeId;
    _committed = '';
    _current = '';
    _lastEmitted = '';
    _heardSpeech = false;
    _restartCount = 0;
    _sessionActive = true;
    final sessionId = ++_sessionId;

    debugPrint('STT session $sessionId start locale=$localeId');
    _notifyStatus(stt.SpeechToText.listeningStatus);
    _scheduleSilenceStop();
    await _listenNow(sessionId);
    return _sessionActive && sessionId == _sessionId;
  }

  Future<void> stop() async {
    final wasActive = _sessionActive;
    _sessionActive = false;
    if (wasActive) _sessionId++;
    _clearTimers();
    _engineStarting = false;
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (e) {
      debugPrint('STT stop error: $e');
    }
    if (wasActive) {
      debugPrint('STT session stopped');
      _notifyStatus(stt.SpeechToText.doneStatus);
    }
  }

  Future<void> cancel() async {
    _sessionActive = false;
    _sessionId++;
    _clearTimers();
    _engineStarting = false;
    try {
      await _speech.cancel();
    } catch (e) {
      debugPrint('STT cancel error: $e');
    }
    _notifyStatus(stt.SpeechToText.doneStatus);
  }

  Future<void> _listenNow(int sessionId) async {
    if (!_sessionActive || sessionId != _sessionId || _engineStarting) return;
    _engineStarting = true;

    try {
      if (_speech.isListening) {
        try {
          await _speech.stop();
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
      if (!_sessionActive || sessionId != _sessionId) return;

      _ignoreEngineEventsUntil =
          DateTime.now().add(const Duration(milliseconds: 450));
      debugPrint('STT listen() locale=$_localeId');
      await _speech.listen(
        onResult: _handleSpeechResult,
        onSoundLevelChange: _handleSoundLevel,
        listenOptions: stt.SpeechListenOptions(
          localeId: _localeId,
          onDevice: false,
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
          pauseFor: const Duration(seconds: 8),
          listenFor: const Duration(minutes: 2),
        ),
      );
    } catch (e, st) {
      debugPrint('STT listen exception: $e\n$st');
      if (_sessionActive && sessionId == _sessionId) {
        _engineStarting = false;
        _scheduleRestart(sessionId);
      }
    } finally {
      if (sessionId == _sessionId) {
        _engineStarting = false;
      }
    }
  }

  void _handleSoundLevel(double level) {
    if (!_sessionActive) return;
    if (level >= _speechRmsThreshold) {
      _scheduleSilenceStop();
    }
  }

  void _handleSpeechResult(SpeechRecognitionResult result) {
    if (!_sessionActive) return;

    final next = _wordsFromResult(result);
    debugPrint(
      'STT result final=${result.finalResult} words="$next" '
      'alts=${result.alternates.length}',
    );
    if (next.isEmpty) return;

    if (_current.isEmpty) {
      _current = next;
    } else if (_isRefinement(_current, next)) {
      if (next.length >= _current.length || result.finalResult) {
        _current = next;
      }
    } else {
      // New burst from the engine — keep the previous words and append.
      _commitCurrent();
      _current = next;
    }

    _heardSpeech = true;
    _restartCount = 0;
    _scheduleSilenceStop();
    _emitText(result.finalResult);

    if (result.finalResult) {
      _commitCurrent();
    }
  }

  bool _isRefinement(String previous, String next) {
    final a = previous.toLowerCase().trim();
    final b = next.toLowerCase().trim();
    if (a.isEmpty || b.isEmpty) return false;
    if (b.startsWith(a) || a.startsWith(b)) return true;
    final aWords = a.split(RegExp(r'\s+'));
    final bWords = b.split(RegExp(r'\s+'));
    return aWords.first == bWords.first;
  }

  String _wordsFromResult(SpeechRecognitionResult result) {
    for (final alt in result.alternates) {
      final words = alt.recognizedWords.trim();
      if (words.isNotEmpty) return words;
      final phrases = alt.recognizedPhrases;
      if (phrases == null || phrases.isEmpty) continue;
      final joined = phrases
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .join(' ');
      if (joined.isNotEmpty) return joined;
    }
    return result.recognizedWords.trim();
  }

  void _commitCurrent() {
    final combined = _combinedText();
    if (combined.isEmpty) return;
    _committed = combined;
    _current = '';
  }

  void _emitText(bool isFinal) {
    var combined = _combinedText().trim();
    if (combined.isEmpty) return;
    if (_lastEmitted.isNotEmpty &&
        combined.length < _lastEmitted.length &&
        !_lastEmitted.toLowerCase().startsWith(combined.toLowerCase())) {
      combined = _lastEmitted;
    }
    if (combined == _lastEmitted && !isFinal) return;
    _lastEmitted = combined;
    _onResult?.call(combined, isFinal);
  }

  String _combinedText() {
    if (_committed.isEmpty) return _current;
    if (_current.isEmpty) return _committed;
    return '$_committed $_current';
  }

  bool _shouldIgnoreEngineEvent() {
    final until = _ignoreEngineEventsUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  void _handleStatus(String status) {
    debugPrint(
      'STT status: $status session=$_sessionActive starting=$_engineStarting',
    );
    if (!_sessionActive) {
      _notifyStatus(status);
      return;
    }

    if (status == stt.SpeechToText.listeningStatus) {
      _notifyStatus(status);
      return;
    }

    if (status == stt.SpeechToText.notListeningStatus ||
        status == stt.SpeechToText.doneStatus) {
      if (_engineStarting || _speech.isListening || _shouldIgnoreEngineEvent()) {
        return;
      }
      _commitCurrent();
      _emitText(true);
      _scheduleRestart(_sessionId);
    }
  }

  void _handleError(SpeechRecognitionError error) {
    debugPrint(
      'STT error: ${error.errorMsg} permanent=${error.permanent} '
      'session=$_sessionActive',
    );
    if (!_sessionActive) return;
    final msg = error.errorMsg.toLowerCase();
    final ignoreStale = _engineStarting || _shouldIgnoreEngineEvent();
    if (ignoreStale && !_isNetworkError(msg) && !_isLanguageError(msg)) {
      debugPrint('STT ignoring error during engine start');
      return;
    }
    if (_isLanguageError(msg) && _localeId != null) {
      debugPrint('STT locale $_localeId not supported; using device default');
      _localeId = null;
      _commitCurrent();
      _emitText(true);
      _scheduleRestart(_sessionId);
      return;
    }

    if (_isRestartableError(msg)) {
      if (_isNetworkError(msg)) {
        _restartCount++;
        if (_restartCount > _maxNetworkRetries && !_heardSpeech) {
          debugPrint('STT giving up after network errors');
          _failSession(error);
          return;
        }
      }
      _commitCurrent();
      _emitText(true);
      _scheduleRestart(_sessionId);
      return;
    }

    _failSession(error);
  }

  Future<void> _failSession(SpeechRecognitionError error) async {
    _sessionActive = false;
    _sessionId++;
    _engineStarting = false;
    _clearTimers();
    try {
      await _speech.stop();
    } catch (_) {}
    _onError?.call(error);
    _notifyStatus(stt.SpeechToText.doneStatus);
  }

  void _scheduleRestart(int sessionId) {
    if (!_sessionActive || sessionId != _sessionId || _engineStarting) return;
    _restartTimer?.cancel();
    _restartTimer = Timer(_restartDelay, () {
      if (!_sessionActive || sessionId != _sessionId) return;
      unawaited(_listenNow(sessionId));
    });
  }

  void _scheduleSilenceStop() {
    _silenceEndTimer?.cancel();
    if (!_sessionActive) return;
    _silenceEndTimer = Timer(_silencePause, () {
      if (_sessionActive) {
        debugPrint('STT silence stop');
        unawaited(stop());
      }
    });
  }

  void _clearTimers() {
    _silenceEndTimer?.cancel();
    _silenceEndTimer = null;
    _restartTimer?.cancel();
    _restartTimer = null;
  }

  void _notifyStatus(String status) {
    _onStatus?.call(status);
  }

  bool _isRestartableError(String msg) {
    return msg.contains('no_match') ||
        msg.contains('speech_timeout') ||
        msg.contains('no speech') ||
        msg.contains('error_busy') ||
        msg.contains('error_client') ||
        msg.contains('error_network') ||
        msg.contains('error_server') ||
        msg.contains('error_retry');
  }

  bool _isNetworkError(String msg) {
    return msg.contains('error_network') || msg.contains('error_server');
  }

  bool _isLanguageError(String msg) {
    return msg.contains('language_not_supported') ||
        msg.contains('language_unavailable');
  }

  bool _localeMatches(String available, String wanted) {
    String norm(String value) =>
        value.replaceAll('-', '_').toLowerCase().trim();
    final left = norm(available);
    final right = norm(wanted);
    if (left == right) return true;
    if (left.startsWith('${right}_')) return true;
    if (right.length <= 3 && left.split('_').first == right) return true;
    return false;
  }
}
