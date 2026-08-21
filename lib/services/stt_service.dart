import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../core/l10n/app_strings.dart';

typedef SttResultHandler = void Function(String recognizedWords, bool isFinal);
typedef SttStatusHandler = void Function(String status);

/// Speech recognition for the For Me composer.
///
/// On Android this uses the Google speech API (same family as Google TTS):
/// live words, Filipino + English together, no in-app model packs.
class SttService {
  SttService() {
    _active = this;
  }

  static SttService? _active;
  static const _native = MethodChannel('com.taptalk/speech');
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _useNative = false;

  bool _ready = false;
  bool _sessionActive = false;
  bool _engineStarting = false;
  bool _capturing = false;
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

  static const Duration _silencePause = Duration(seconds: 5);
  static const Duration _restartDelay = Duration(milliseconds: 400);
  static const int _maxNetworkRetries = 6;
  static const double _speechRmsThreshold = 2;

  bool get isListening => _sessionActive;
  bool get isCapturing => _capturing;
  bool get isReady => _ready;

  Future<bool> hasPack(String? locale) async => true;

  /// Drops the mic so Android TTS can use the speaker.
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

    if (!kIsWeb && Platform.isAndroid) {
      try {
        _native.setMethodCallHandler(_onNativeCall);
        _useNative = true;
        _ready = true;
        debugPrint('STT using Google bilingual speech API');
        return true;
      } catch (e) {
        debugPrint('STT native init failed: $e');
      }
    }

    _ready = await _speech.initialize(
      debugLogging: true,
      options: [
        stt.SpeechToText.androidNoBluetooth,
      ],
      onStatus: _handleStatus,
      onError: _handleError,
    );
    debugPrint('STT initialize ready=$_ready native=$_useNative');
    return _ready;
  }

  Future<String?> resolveLocale(AppLanguage lang) async {
    if (_useNative) {
      debugPrint('STT Google API languages=fil-PH + en-US');
      return 'fil-PH';
    }

    final locales = await _speech.locales();
    debugPrint(
      'STT locales (${locales.length}) appLang=$lang: '
      '${locales.map((l) => l.localeId).join(', ')}',
    );
    final preferred = lang == AppLanguage.filipino
        ? ['fil_PH', 'tl_PH', 'fil', 'tl', 'en_PH', 'en_US']
        : ['en_US', 'en_PH', 'en_GB', 'en'];
    for (final want in preferred) {
      final match = locales.where(
        (l) => l.localeId.toLowerCase().replaceAll('-', '_') ==
            want.toLowerCase().replaceAll('-', '_'),
      );
      if (match.isNotEmpty) return match.first.localeId;
    }
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
    _capturing = false;
    _sessionActive = true;
    final sessionId = ++_sessionId;

    debugPrint('STT session $sessionId start locale=$localeId');
    await _listenNow(sessionId);
    return _sessionActive && sessionId == _sessionId;
  }

  Future<void> stop() async {
    final wasActive = _sessionActive;
    _sessionActive = false;
    _capturing = false;
    if (wasActive) _sessionId++;
    _clearTimers();
    _engineStarting = false;
    try {
      if (_useNative) {
        await _native.invokeMethod('stop');
      } else if (_speech.isListening) {
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
    _capturing = false;
    _sessionId++;
    _clearTimers();
    _engineStarting = false;
    try {
      if (_useNative) {
        await _native.invokeMethod('cancel');
      } else {
        await _speech.cancel();
      }
    } catch (e) {
      debugPrint('STT cancel error: $e');
    }
    _notifyStatus(stt.SpeechToText.doneStatus);
  }

  Future<void> _listenNow(int sessionId) async {
    if (!_sessionActive || sessionId != _sessionId || _engineStarting) return;
    _engineStarting = true;

    try {
      if (_useNative) {
        debugPrint('STT native listen() locale=$_localeId');
        await _native.invokeMethod('start', {'locale': _localeId});
      } else {
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
      }
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

  Future<dynamic> _onNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onResult':
        final args = Map<dynamic, dynamic>.from(call.arguments as Map);
        final words = (args['words'] as String? ?? '').trim();
        final isFinal = args['final'] == true;
        debugPrint('STT native result final=$isFinal words="$words"');
        _applyRecognizedWords(words, isFinal);
        return null;
      case 'onError':
        final msg = call.arguments?.toString() ?? 'error_unknown';
        _handleError(SpeechRecognitionError(msg, true));
        return null;
      case 'onStatus':
        _handleStatus(call.arguments?.toString() ?? '');
        return null;
      default:
        return null;
    }
  }

  void _handleSoundLevel(double level) {
    if (!_sessionActive) return;
    if (level >= _speechRmsThreshold) {
      _scheduleSilenceStop();
    }
  }

  void _handleSpeechResult(SpeechRecognitionResult result) {
    final next = _wordsFromResult(result);
    debugPrint(
      'STT result final=${result.finalResult} words="$next" '
      'alts=${result.alternates.length}',
    );
    _applyRecognizedWords(next, result.finalResult);
  }

  void _applyRecognizedWords(String next, bool isFinal) {
    if (!_sessionActive) return;
    if (next.isEmpty) return;

    if (_current.isEmpty) {
      _current = next;
    } else if (_isRefinement(_current, next)) {
      if (next.length >= _current.length || isFinal) {
        _current = next;
      }
    } else {
      _commitCurrent();
      _current = next;
    }

    _heardSpeech = true;
    _restartCount = 0;
    _scheduleSilenceStop();
    _emitText(isFinal);

    if (isFinal) {
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
      'STT status: $status session=$_sessionActive starting=$_engineStarting '
      'capturing=$_capturing',
    );
    if (status == 'downloading' || status == 'loading') {
      _notifyStatus(status);
      return;
    }

    if (!_sessionActive) {
      _capturing = false;
      _notifyStatus(status);
      return;
    }

    if (status == stt.SpeechToText.listeningStatus) {
      _capturing = true;
      _engineStarting = false;
      _scheduleSilenceStop();
      _notifyStatus(status);
      return;
    }

    if (status == stt.SpeechToText.notListeningStatus ||
        status == stt.SpeechToText.doneStatus) {
      _capturing = false;
      if (_useNative) {
        // Vosk keeps one session alive; "done" here means the engine stopped.
        if (_engineStarting || _shouldIgnoreEngineEvent()) return;
        _commitCurrent();
        _emitText(true);
        _scheduleRestart(_sessionId);
        return;
      }
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
    if (_isPackError(msg)) {
      _failSession(error);
      return;
    }
    final ignoreStale = _engineStarting || _shouldIgnoreEngineEvent();
    if (ignoreStale && !_isNetworkError(msg) && !_isLanguageError(msg)) {
      debugPrint('STT ignoring error during engine start');
      return;
    }
    if (_isLanguageError(msg)) {
      debugPrint('STT language error on $_localeId; using device default');
      _localeId = null;
      _commitCurrent();
      _emitText(true);
      _scheduleRestart(_sessionId);
      return;
    }

    if (_isRestartableError(msg)) {
      _restartCount++;
      if (_restartCount > _maxNetworkRetries && !_heardSpeech) {
        debugPrint('STT giving up after repeated errors');
        _failSession(error);
        return;
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
    _capturing = false;
    _sessionId++;
    _engineStarting = false;
    _clearTimers();
    try {
      if (_useNative) {
        await _native.invokeMethod('stop');
      } else {
        await _speech.stop();
      }
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
    if (!_sessionActive || !_capturing) return;
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

  bool _isPackError(String msg) {
    return msg.contains('error_pack') || msg.contains('cancelled');
  }
}
