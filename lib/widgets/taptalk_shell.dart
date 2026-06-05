import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';

/// Edge-to-edge shell: background extends behind the status bar and nav bar.
class TapTalkShell extends StatelessWidget {
  const TapTalkShell({
    super.key,
    required this.child,
    this.fillHeight = true,
    this.backgroundColor,
    /// Light status bar icons (clock, battery) for dark/colored headers.
    this.coloredHeader = false,
  });

  final Widget child;
  final bool fillHeight;
  final Color? backgroundColor;
  final bool coloredHeader;

  static const _lightBackgroundOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static const _coloredHeaderOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppState>().theme;
    final bg = backgroundColor ?? theme.bgLight;
    final overlay =
        coloredHeader ? _coloredHeaderOverlay : _lightBackgroundOverlay;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: bg,
        body: fillHeight
            ? SizedBox.expand(
                child: Material(
                  color: bg,
                  clipBehavior: Clip.antiAlias,
                  child: child,
                ),
              )
            : Material(
                color: bg,
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
      ),
    );
  }
}
