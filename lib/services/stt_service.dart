import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../core/l10n/app_strings.dart';

typedef SttResultHandler = void Function(String recognizedWords, bool isFinal);
typedef SttStatusHandler = void Function(String status);

/// Speech recognition for the For Me composer.
class SttService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _ready = false;
  bool _listening = false;
  Timer? _silenceEndTimer;
  SttStatusHandler? _onStatus;
  void Function(SpeechRecognitionError error)? _onError;

  static const Duration _silencePause = Duration(seconds: 3);

  bool get isListening => _listening;
  bool get isReady => _ready;

  Future<bool> initialize({
    SttStatusHandler? onStatus,
    void Function(SpeechRecognitionError error)? onError,
  }) async {
    _onStatus = onStatus;
    _onError = onError;

    if (_ready) return true;

    _ready = await _speech.initialize(
      options: [
        stt.SpeechToText.androidNoBluetooth,
        stt.SpeechToText.androidIntentLookup,
      ],
      onStatus: _handleStatus,
      onError: _handleError,
    );
    return _ready;
  }

  void _handleStatus(String status) {
    if (status == stt.SpeechToText.listeningStatus) {
      _listening = true;
    } else if (status == stt.SpeechToText.notListeningStatus ||
        status == stt.SpeechToText.doneStatus) {
      _endListening();
    }
    _onStatus?.call(status);
  }

  bool _isBenignRuntimeError(SpeechRecognitionError error) {
    final msg = error.errorMsg.toLowerCase();
    return msg.contains('no_match') ||
        msg.contains('speech_timeout') ||
        msg.contains('no speech');
  }

  void _handleError(SpeechRecognitionError error) {
    if (_isBenignRuntimeError(error)) {
      _endListening();
      _onStatus?.call(stt.SpeechToText.doneStatus);
      return;
    }
    _endListening();
    _onError?.call(error);
  }

  void _clearSilenceTimer() {
    _silenceEndTimer?.cancel();
    _silenceEndTimer = null;
  }

  void _scheduleSilenceStop() {
    _clearSilenceTimer();
    if (!_listening) return;
    _silenceEndTimer = Timer(_silencePause, () {
      if (_listening) {
        unawaited(stop());
      }
    });
  }

  void _handleSpeechResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords;
    if (words.trim().isNotEmpty) {
      _scheduleSilenceStop();
    }
  }

  void _endListening() {
    _listening = false;
    _clearSilenceTimer();
  }

  Future<String> resolveLocale(AppLanguage lang) async {
    final locales = await _speech.locales();
    final preferred = lang == AppLanguage.filipino
        ? ['fil_PH', 'tl_PH', 'en_US']
        : ['en_US', 'en_GB'];
    for (final localeId in preferred) {
      if (locales.any((l) => l.localeId == localeId)) {
        return localeId;
      }
    }
    return preferred.first;
  }

  Future<bool> startListening({
    required String localeId,
    required SttResultHandler onResult,
  }) async {
    if (!_ready) return false;

    await _ensureIdle();

    try {
      await _speech.listen(
        onResult: (result) {
          _handleSpeechResult(result);
          onResult(result.recognizedWords, result.finalResult);
        },
        listenOptions: stt.SpeechListenOptions(
          localeId: localeId,
          onDevice: false,
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
          pauseFor: const Duration(seconds: 30),
          listenFor: const Duration(minutes: 2),
        ),
      );
    } catch (_) {
      _endListening();
      return false;
    }

    for (var i = 0; i < 40; i++) {
      if (_speech.isListening || _listening) return true;
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }

    _listening = true;
    return true;
  }

  Future<void> _ensureIdle() async {
    if (!_speech.isListening && !_listening) return;
    try {
      await _speech.stop();
    } catch (_) {}
    for (var i = 0; i < 20; i++) {
      if (!_speech.isListening) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    _endListening();
  }

  Future<void> stop() async {
    _endListening();
    try {
      await _speech.stop();
    } catch (_) {}
    for (var i = 0; i < 20; i++) {
      if (!_speech.isListening) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    _onStatus?.call(stt.SpeechToText.doneStatus);
  }

  Future<void> cancel() async {
    _endListening();
    try {
      await _speech.cancel();
    } catch (_) {}
    _onStatus?.call(stt.SpeechToText.doneStatus);
  }
}
