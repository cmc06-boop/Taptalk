import 'package:flutter/material.dart';

/// Consistent layout tokens (replaces mixed 4/6/10/14px margins in the web prototype).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;

  static const double radiusSm = 12;
  static const double radiusMd = 18;
  static const double radiusLg = 22;
  static const double radiusXl = 55;

  static const double phoneMaxWidth = 390;
  static const double tabletMaxWidth = 720;
  static const double desktopMaxWidth = 960;

  static EdgeInsets screenPadding(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 1100) {
      return const EdgeInsets.symmetric(horizontal: xl, vertical: lg);
    }
    if (w >= 600) {
      return const EdgeInsets.symmetric(horizontal: lg, vertical: md);
    }
    return const EdgeInsets.symmetric(horizontal: lg);
  }

  static double contentMaxWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 1100) return desktopMaxWidth;
    if (w >= 600) return tabletMaxWidth;
    return phoneMaxWidth;
  }

  static int phraseGridColumns(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 1100) return 3;
    if (w >= 600) return 3;
    return 2;
  }
}
