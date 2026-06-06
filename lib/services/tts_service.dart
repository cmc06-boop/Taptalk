import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../core/constants/tts_speed_options.dart';
import '../core/l10n/app_strings.dart';

class TtsService {
  FlutterTts _tts = FlutterTts();
  bool _ready = false;
  String? _resolvedLanguageCode;
  bool _initializing = false;
  VoidCallback? onStart;
  void Function(String text, int start, int end, String word)? onProgress;
  VoidCallback? onComplete;
  void Function(String message)? onError;

  Future<void> _configureTts() async {
    _tts.setStartHandler(() => onStart?.call());
    _tts.setProgressHandler((text, start, end, word) {
      onProgress?.call(text, start, end, word);
    });
    _tts.setCompletionHandler(() => onComplete?.call());
    _tts.setCancelHandler(() => onComplete?.call());
    _tts.setErrorHandler((message) => onError?.call(message));
    await _tts.awaitSpeakCompletion(true);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _tts.setSharedInstance(true);
    }
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _tts.setEngine('com.google.android.tts');
      } catch (_) {
        // Keep default engine if Google TTS is unavailable.
      }
    }
  }

  Future<void> _recreateEngine() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _tts = FlutterTts();
    _ready = false;
    await init();
  }

  Future<void> init() async {
    if (_ready || _initializing) return;
    _initializing = true;
    try {
      await _configureTts();
      _ready = true;
    } finally {
      _initializing = false;
    }
  }

  /// Maps user multiplier (1.0 = normal) to [setSpeechRate] values.
  ///
  /// flutter_tts uses 0.5 as normal on mobile/desktop (Android, iOS, macOS,
  /// Windows). Web Speech API uses 1.0 as normal, so web keeps the user rate.
  static double nativeSpeechRate(double userRate) {
    final rate = TtsSpeedOptions.snap(userRate);
    if (kIsWeb) return rate;
    return rate * 0.5;
  }

  static bool _languageAvailable(dynamic result) {
    if (result is bool) return result;
    if (result is int) return result == 1;
    if (result is String) {
      final v = result.toLowerCase();
      return v == '1' || v == 'true';
    }
    return false;
  }

  Future<String> resolveLanguageCode(AppLanguage lang) async {
    await init();

    final primary = lang == AppLanguage.filipino ? 'fil-PH' : 'en-US';
    final fallback = lang == AppLanguage.filipino ? 'tl-PH' : 'en-GB';
    const hardFallback = 'en-US';
    try {
      if (_languageAvailable(await _tts.isLanguageAvailable(primary))) {
        return primary;
      }
      if (_languageAvailable(await _tts.isLanguageAvailable(fallback))) {
        return fallback;
      }
      if (_languageAvailable(await _tts.isLanguageAvailable(hardFallback))) {
        return hardFallback;
      }
    } catch (_) {}
    return hardFallback;
  }

  Future<bool> speak(
    String text, {
    double rate = 1.0,
    AppLanguage lang = AppLanguage.english,
  }) async {
    if (text.trim().isEmpty) return false;

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        if (attempt == 0) {
          await init();
        } else {
          await _recreateEngine();
          await Future<void>.delayed(Duration(milliseconds: 220 * attempt));
        }

        final languageCode = await resolveLanguageCode(lang);
        _resolvedLanguageCode = languageCode;
        await _tts.setSpeechRate(nativeSpeechRate(rate));
        try {
          await _tts.setLanguage(languageCode);
        } catch (_) {
          _resolvedLanguageCode = 'en-US';
          await _tts.setLanguage('en-US');
        }
        final result = await _tts.speak(text.trim());
        final ok = result == null ||
            result == 1 ||
            result == '1' ||
            result == 'success' ||
            result == true ||
            result.toString().toLowerCase() == 'ok';
        if (ok) return true;
      } catch (_) {
        // Retry by recreating the engine in the next loop iteration.
      }
    }
    onError?.call('speak_failed');
    return false;
  }

  String? get lastLanguageCode => _resolvedLanguageCode;

  Future<void> pause() async {
    try {
      await _tts.pause();
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
