import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../core/constants/tts_speed_options.dart';
import '../core/l10n/app_strings.dart';

class TtsService {
  FlutterTts _tts = FlutterTts();
  bool _ready = false;
  String? _resolvedLanguageCode;
  bool _initializing = false;
  int _speakEpoch = 0;
  VoidCallback? onStart;
  void Function(String text, int start, int end, String word)? onProgress;
  VoidCallback? onComplete;
  void Function(String message)? onError;

  static bool get _isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  Future<void> _configureTts() async {
    _tts.setStartHandler(() => onStart?.call());
    _tts.setProgressHandler((text, start, end, word) {
      onProgress?.call(text, start, end, word);
    });
    _tts.setCompletionHandler(() => onComplete?.call());
    _tts.setCancelHandler(() => onComplete?.call());
    _tts.setErrorHandler((message) => onError?.call(message));

    // Windows SAPI/UWP backends hang or fail silently when this is true.
    await _tts.awaitSpeakCompletion(!_isWindows);

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
    if (_isWindows) {
      await _prepareWindowsVoice();
    }
  }

  Future<void> _recreateEngine() async {
    try {
      await _tts.stop();
    } catch (_) {}
    if (_isWindows) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
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

  static bool _speakResultOk(dynamic result) {
    return result == null ||
        result == 1 ||
        result == '1' ||
        result == 'success' ||
        result == true ||
        result.toString().toLowerCase() == 'ok';
  }

  Future<List<String>> _installedLanguages() async {
    try {
      final raw = await _tts.getLanguages;
      if (raw is! List) return const [];
      return raw.map((entry) => entry.toString()).toList();
    } catch (_) {
      return const [];
    }
  }

  String _pickInstalledLanguage(List<String> languages, List<String> preferred) {
    for (final code in preferred) {
      final normalized = code.toLowerCase();
      for (final language in languages) {
        final candidate = language.toLowerCase();
        if (candidate == normalized || candidate.startsWith('$normalized-')) {
          return language;
        }
      }
    }
    return languages.isNotEmpty ? languages.first : 'en-US';
  }

  Future<String> _resolveWindowsLanguage(AppLanguage lang) async {
    final languages = await _installedLanguages();
    if (lang == AppLanguage.filipino) {
      return _pickInstalledLanguage(
        languages,
        const ['fil-PH', 'tl-PH', 'fil', 'tl', 'en-US', 'en-GB', 'en'],
      );
    }
    return _pickInstalledLanguage(
      languages,
      const ['en-US', 'en-GB', 'en-PH', 'en'],
    );
  }

  Future<void> _applyWindowsVoice(String languageCode) async {
    try {
      final raw = await _tts.getVoices;
      if (raw is! List || raw.isEmpty) {
        await _tts.setLanguage(languageCode);
        return;
      }

      final normalized = languageCode.toLowerCase();
      final prefix = normalized.split('-').first;

      Map<dynamic, dynamic>? best;
      Map<dynamic, dynamic>? englishFallback;
      Map<dynamic, dynamic>? anyFallback;

      for (final entry in raw) {
        if (entry is! Map) continue;
        anyFallback ??= entry;
        final locale = entry['locale']?.toString() ?? '';
        final name = entry['name']?.toString() ?? '';
        final localeLower = locale.toLowerCase();
        final isEnglish =
            localeLower.startsWith('en') || localeLower.contains('english');
        if (isEnglish) {
          englishFallback ??= entry;
        }

        final localeMatches = localeLower == normalized ||
            localeLower.startsWith('$prefix-') ||
            (prefix.length >= 2 && localeLower.startsWith(prefix));
        if (!localeMatches) continue;

        if (name.toLowerCase().contains('microsoft')) {
          best = entry;
          break;
        }
        best ??= entry;
      }

      best ??= englishFallback ?? anyFallback;
      if (best == null) {
        await _tts.setLanguage(languageCode);
        return;
      }

      await _tts.setVoice(<String, String>{
        'name': best['name']?.toString() ?? '',
        'locale': best['locale']?.toString() ?? languageCode,
      });
    } catch (e, st) {
      debugPrint('Windows voice setup failed: $e\n$st');
      try {
        await _tts.setLanguage(languageCode);
      } catch (_) {}
    }
  }

  Future<void> _prepareWindowsVoice() async {
    await _applyWindowsVoice(await _resolveWindowsLanguage(AppLanguage.english));
  }

  Future<String> resolveLanguageCode(AppLanguage lang) async {
    await init();

    if (_isWindows) {
      return _resolveWindowsLanguage(lang);
    }

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

  Future<void> _ensureWindowsIdle() async {
    try {
      await _tts.stop();
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  Future<bool> _speakAndWaitForCompletion(String text) async {
    if (!_isWindows) {
      final result = await _tts.speak(text);
      return _speakResultOk(result);
    }

    // Windows plays audio asynchronously; waiting on onComplete is unreliable
    // because stop/cancel events and MediaPlayer callbacks can race.
    await _ensureWindowsIdle();
    await _tts.setVolume(1.0);

    var result = await _tts.speak(text);
    if (!_speakResultOk(result)) {
      await _ensureWindowsIdle();
      result = await _tts.speak(text);
    }
    return _speakResultOk(result);
  }

  Future<bool> speak(
    String text, {
    double rate = 1.0,
    AppLanguage lang = AppLanguage.english,
  }) async {
    if (text.trim().isEmpty) return false;

    final epoch = ++_speakEpoch;

    for (var attempt = 0; attempt < 3; attempt++) {
      if (epoch != _speakEpoch) return false;
      try {
        if (attempt == 0) {
          await init();
        } else {
          await _recreateEngine();
          await Future<void>.delayed(Duration(milliseconds: 220 * attempt));
        }
        if (epoch != _speakEpoch) return false;

        final languageCode = await resolveLanguageCode(lang);
        _resolvedLanguageCode = languageCode;
        await _tts.setSpeechRate(nativeSpeechRate(rate));
        if (_isWindows) {
          await _applyWindowsVoice(languageCode);
          await _tts.setVolume(1.0);
        } else {
          try {
            await _tts.setLanguage(languageCode);
          } catch (_) {
            _resolvedLanguageCode = 'en-US';
            await _tts.setLanguage('en-US');
          }
        }

        final ok = await _speakAndWaitForCompletion(text.trim());
        if (epoch != _speakEpoch) return false;
        if (ok) return true;
      } catch (e, st) {
        if (epoch != _speakEpoch) return false;
        debugPrint('TTS speak attempt $attempt failed: $e\n$st');
      }
    }
    if (epoch != _speakEpoch) return false;
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
    _speakEpoch++;
    try {
      await _tts.stop();
      if (_isWindows) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    } catch (_) {}
  }
}
