import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../core/l10n/app_strings.dart';

typedef SttResultHandler = void Function(String recognizedWords, bool isFinal);

/// On-device speech recognition for the For Me composer (works offline when
/// the device has a local recognition model installed).
class SttService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _ready = false;
  bool _listening = false;

  bool get isListening => _listening;
  bool get isReady => _ready;

  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(SpeechRecognitionError error)? onError,
  }) async {
    if (_ready) return true;
    _ready = await _speech.initialize(
      options: [
        stt.SpeechToText.androidIntentLookup,
        stt.SpeechToText.androidNoBluetooth,
      ],
      onStatus: (status) {
        if (status == stt.SpeechToText.notListeningStatus ||
            status == stt.SpeechToText.doneStatus) {
          _listening = false;
        }
        onStatus?.call(status);
      },
      onError: (error) {
        _listening = false;
        onError?.call(error);
      },
    );
    return _ready;
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
    return preferred.last;
  }

  Future<bool> startListening({
    required String localeId,
    required SttResultHandler onResult,
  }) async {
    if (!_ready) return false;
    _listening = true;
    try {
      final started = await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          localeId: localeId,
          onDevice: true,
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
        ),
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
        },
      );
      if (started != true) {
        _listening = false;
        return false;
      }
      return true;
    } catch (_) {
      _listening = false;
      return false;
    }
  }

  Future<void> stop() async {
    await _speech.stop();
    _listening = false;
  }

  Future<void> cancel() async {
    await _speech.cancel();
    _listening = false;
  }
}
