import 'package:flutter/material.dart';

class TapTalkThemeToken {
  const TapTalkThemeToken({
    required this.key,
    required this.name,
    required this.bgLight,
    required this.bgMid,
    required this.bgAccent,
    required this.textMain,
  });

  final String key;
  final String name;
  final Color bgLight;
  final Color bgMid;
  final Color bgAccent;
  final Color textMain;

  ColorScheme get colorScheme => ColorScheme(
        brightness: Brightness.light,
        primary: bgAccent,
        onPrimary: Colors.white,
        secondary: bgMid,
        onSecondary: textMain,
        surface: bgLight,
        onSurface: textMain,
        error: const Color(0xFFC62828),
        onError: Colors.white,
      );

  /// Darker accent for readable labels/icons on tinted surfaces (e.g. drawer).
  Color get accentEmphasis => Color.lerp(bgAccent, textMain, 0.58)!;
}

abstract final class TapTalkThemes {
  static const TapTalkThemeToken appDefault = TapTalkThemeToken(
    key: 'app_default',
    name: 'App Default',
    bgLight: Color(0xFFEAF9F1),
    bgMid: Color(0xFFCBEFDC),
    bgAccent: Color(0xFF49C488),
    textMain: Color(0xFF1E3A2C),
  );

  static const List<TapTalkThemeToken> all = [
    TapTalkThemeToken(
      key: 'calm_blue',
      name: 'Calm Blue',
      bgLight: Color(0xFFE4F4FF),
      bgMid: Color(0xFFC5E8FF),
      bgAccent: Color(0xFF46A6FF),
      textMain: Color(0xFF0C3E66),
    ),
    TapTalkThemeToken(
      key: 'soft_purple',
      name: 'Equality Purple',
      bgLight: Color(0xFFF2E9FF),
      bgMid: Color(0xFFE2D0FF),
      bgAccent: Color(0xFF9A68FF),
      textMain: Color(0xFF3A2870),
    ),
    TapTalkThemeToken(
      key: 'mint_green',
      name: 'Growth Green',
      bgLight: Color(0xFFE6FAEF),
      bgMid: Color(0xFFC9F2DB),
      bgAccent: Color(0xFF3FCF8E),
      textMain: Color(0xFF1D4A36),
    ),
    TapTalkThemeToken(
      key: 'soft_orange',
      name: 'Empower Orange',
      bgLight: Color(0xFFFFF0E6),
      bgMid: Color(0xFFFFDCC6),
      bgAccent: Color(0xFFFF8A4C),
      textMain: Color(0xFF6C3C1E),
    ),
    TapTalkThemeToken(
      key: 'sun_yellow',
      name: 'Joy Yellow',
      bgLight: Color(0xFFFFF7D9),
      bgMid: Color(0xFFFFEB9C),
      bgAccent: Color(0xFFFFC62E),
      textMain: Color(0xFF5E4900),
    ),
    TapTalkThemeToken(
      key: 'peach',
      name: 'Care Peach',
      bgLight: Color(0xFFFFE7F1),
      bgMid: Color(0xFFFFCBE0),
      bgAccent: Color(0xFFFF6FA6),
      textMain: Color(0xFF6E2240),
    ),
    TapTalkThemeToken(
      key: 'sky',
      name: 'Sky Calm',
      bgLight: Color(0xFFE4F8FF),
      bgMid: Color(0xFFC3EEFF),
      bgAccent: Color(0xFF45C6FF),
      textMain: Color(0xFF114B66),
    ),
    TapTalkThemeToken(
      key: 'lavender',
      name: 'Calm Lavender',
      bgLight: Color(0xFFF4E9FF),
      bgMid: Color(0xFFE4D1FF),
      bgAccent: Color(0xFFB06DFF),
      textMain: Color(0xFF4A2B75),
    ),
    TapTalkThemeToken(
      key: 'teal',
      name: 'Focus Teal',
      bgLight: Color(0xFFE1FBF8),
      bgMid: Color(0xFFBFF4EF),
      bgAccent: Color(0xFF26C8BE),
      textMain: Color(0xFF0B5752),
    ),
    TapTalkThemeToken(
      key: 'light_gray',
      name: 'Fresh Stone',
      bgLight: Color(0xFFF3F5F9),
      bgMid: Color(0xFFE0E6F0),
      bgAccent: Color(0xFF7C8FB0),
      textMain: Color(0xFF2D3A4F),
    ),
  ];

  static TapTalkThemeToken byKey(String? key) {
    if (key == appDefault.key) return appDefault;
    return all.firstWhere(
      (t) => t.key == key,
      orElse: () => appDefault,
    );
  }
}
