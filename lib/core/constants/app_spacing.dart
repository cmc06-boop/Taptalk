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

  static const Duration drawerAnimation = Duration(milliseconds: 300);

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

  /// Phrase grids: 2 columns on phone, 3 on tablet, 5 on desktop/Windows.
  static int phraseGridColumns(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 1100) return 5;
    if (w >= 600) return 3;
    return 2;
  }

  static bool phraseGridIsDense(BuildContext context) =>
      phraseGridColumns(context) >= 3;

  static double phraseGridChildAspectRatio(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final scaleBoost = textScale > 1.05 ? (textScale - 1) * 0.12 : 0.0;
    if (w >= 1100) return 0.84 - scaleBoost;
    if (w >= 600) return 0.78 - scaleBoost;
    return 0.78 - scaleBoost;
  }

  static SliverGridDelegateWithFixedCrossAxisCount phraseGridDelegate(
    BuildContext context,
  ) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: phraseGridColumns(context),
      crossAxisSpacing: sm,
      mainAxisSpacing: sm,
      childAspectRatio: phraseGridChildAspectRatio(context),
    );
  }

  /// Category picker grid: 3 columns on phone, 5 on tablet and wider.
  static int categoryGridColumns(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 600) return 5;
    return 3;
  }
}
