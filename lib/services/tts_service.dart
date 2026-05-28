import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../core/constants/tts_speed_options.dart';
import '../core/l10n/app_strings.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  String? _resolvedLanguageCode;

  Future<void> init() async {
    if (_ready) return;

    await _tts.awaitSpeakCompletion(true);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _ready = true;
  }

  /// Maps user multiplier (1.0 = normal) to platform [setSpeechRate] values.
  static double nativeSpeechRate(double userRate) {
    final rate = TtsSpeedOptions.snap(userRate);
    if (defaultTargetPlatform == TargetPlatform.android) {
      return rate;
    }
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
    try {
      if (_languageAvailable(await _tts.isLanguageAvailable(primary))) {
        return primary;
      }
      if (_languageAvailable(await _tts.isLanguageAvailable(fallback))) {
        return fallback;
      }
    } catch (_) {}
    return primary;
  }

  Future<bool> speak(
    String text, {
    double rate = 1.0,
    AppLanguage lang = AppLanguage.english,
  }) async {
    if (text.trim().isEmpty) return false;

    try {
      await init();
      await _tts.stop();

      final languageCode = await resolveLanguageCode(lang);
      _resolvedLanguageCode = languageCode;

      await _tts.setSpeechRate(nativeSpeechRate(rate));
      await _tts.setLanguage(languageCode);
      final result = await _tts.speak(text.trim());
      return result == 1 || result == '1' || result == 'success' || result == true;
    } catch (_) {
      return false;
    }
  }

  String? get lastLanguageCode => _resolvedLanguageCode;

  Future<void> pause() => _tts.pause();

  Future<void> stop() => _tts.stop();
}
