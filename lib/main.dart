import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/utils/phrase_image_storage.dart';
import 'core/utils/phrase_video_poster.dart';

Future<void> _initializeIntlLocales() async {
  await Future.wait([
    initializeDateFormatting('en_US'),
    initializeDateFormatting('fil_PH'),
  ]);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeIntlLocales();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await Future.wait([
    warmPhraseImageCacheDirectory(),
    warmPhraseVideoPosterDirectory(),
  ]);
  // Release/offline: bundle all Poppins weights under assets/fonts.
  // Debug: allow CDN for weights like Medium/ExtraBold not in pubspec yet.
  GoogleFonts.config.allowRuntimeFetching = kDebugMode;
  runApp(const TapTalkApp());
}
