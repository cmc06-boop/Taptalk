import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';

/// Edge-to-edge shell on all devices (phone, tablet, desktop, web).
class TapTalkShell extends StatelessWidget {
  const TapTalkShell({
    super.key,
    required this.child,
    this.fillHeight = true,
    this.backgroundColor,
  });

  final Widget child;
  final bool fillHeight;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppState>().theme;
    final bg = backgroundColor ?? theme.bgLight;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: fillHeight
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
