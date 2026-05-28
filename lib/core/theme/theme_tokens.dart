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
}

abstract final class TapTalkThemes {
  static const TapTalkThemeToken appDefault = TapTalkThemeToken(
    key: 'app_default',
    name: 'App Default',
    bgLight: Color(0xFFF5F7FA),
    bgMid: Color(0xFFE8EDF3),
    bgAccent: Color(0xFF64748B),
    textMain: Color(0xFF1F2937),
  );

  static const List<TapTalkThemeToken> all = [
    TapTalkThemeToken(
      key: 'calm_blue',
      name: 'Calm Blue',
      bgLight: Color(0xFFDAEEF6),
      bgMid: Color(0xFFB8DCEA),
      bgAccent: Color(0xFF6AAFC8),
      textMain: Color(0xFF003049),
    ),
    TapTalkThemeToken(
      key: 'soft_purple',
      name: 'Equality Purple',
      bgLight: Color(0xFFEDE5FB),
      bgMid: Color(0xFFD9CAF5),
      bgAccent: Color(0xFF9B7DD4),
      textMain: Color(0xFF2B2D42),
    ),
    TapTalkThemeToken(
      key: 'mint_green',
      name: 'Growth Green',
      bgLight: Color(0xFFD6F3E3),
      bgMid: Color(0xFFB3E6CC),
      bgAccent: Color(0xFF5BB88A),
      textMain: Color(0xFF1B4332),
    ),
    TapTalkThemeToken(
      key: 'soft_orange',
      name: 'Empower Orange',
      bgLight: Color(0xFFF7EDE3),
      bgMid: Color(0xFFF5DCC8),
      bgAccent: Color(0xFFE97B54),
      textMain: Color(0xFF5C3D2E),
    ),
    TapTalkThemeToken(
      key: 'sun_yellow',
      name: 'Joy Yellow',
      bgLight: Color(0xFFFDF8D0),
      bgMid: Color(0xFFFAEEA0),
      bgAccent: Color(0xFFC9A800),
      textMain: Color(0xFF4A4200),
    ),
    TapTalkThemeToken(
      key: 'peach',
      name: 'Care Peach',
      bgLight: Color(0xFFFDE0EC),
      bgMid: Color(0xFFF9C0D8),
      bgAccent: Color(0xFFE0669A),
      textMain: Color(0xFF5A0F2E),
    ),
    TapTalkThemeToken(
      key: 'sky',
      name: 'Sky Calm',
      bgLight: Color(0xFFD8F4FB),
      bgMid: Color(0xFFB0E8F5),
      bgAccent: Color(0xFF4DBEDD),
      textMain: Color(0xFF023047),
    ),
    TapTalkThemeToken(
      key: 'lavender',
      name: 'Calm Lavender',
      bgLight: Color(0xFFF0E2FD),
      bgMid: Color(0xFFDDC4F9),
      bgAccent: Color(0xFFA459E0),
      textMain: Color(0xFF3C096C),
    ),
    TapTalkThemeToken(
      key: 'teal',
      name: 'Focus Teal',
      bgLight: Color(0xFFD0F7F4),
      bgMid: Color(0xFFA0EEEA),
      bgAccent: Color(0xFF3BBDB7),
      textMain: Color(0xFF004D40),
    ),
    TapTalkThemeToken(
      key: 'light_gray',
      name: 'Neutral Calm',
      bgLight: Color(0xFFF0F0F0),
      bgMid: Color(0xFFDCDCDC),
      bgAccent: Color(0xFF888888),
      textMain: Color(0xFF333333),
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
