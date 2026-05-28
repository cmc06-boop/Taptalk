import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Use bundled Poppins only — no Google Fonts CDN (works without internet).
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const TapTalkApp());
}
