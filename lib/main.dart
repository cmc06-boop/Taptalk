import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Release/offline: bundle all Poppins weights under assets/fonts.
  // Debug: allow CDN for weights like Medium/ExtraBold not in pubspec yet.
  GoogleFonts.config.allowRuntimeFetching = kDebugMode;
  await FirebaseService.instance.initialize();
  runApp(const TapTalkApp());
}
