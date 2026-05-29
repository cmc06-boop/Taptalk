import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import 'app_header.dart';
import 'bottom_nav_bar.dart';
import 'source_drawer.dart';
import 'taptalk_shell.dart';

class LearnerScaffold extends StatelessWidget {
  const LearnerScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.currentRoute,
    this.onMicTap,
    this.micActive = false,
    this.showBottomNav = true,
  });

  final String title;
  final Widget body;
  final AppRoute currentRoute;
  final VoidCallback? onMicTap;
  final bool micActive;
  final bool showBottomNav;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isParent = app.user?.isParent ?? false;

    return TapTalkShell(
      child: Stack(
          children: [
            Column(
              children: [
                AppHeader(
                  title: title,
                  onMenu: () => app.toggleDrawer(),
                  showProfile: !isParent,
                  showNotifications: isParent,
                  onProfile: () => app.setRoute(AppRoute.profile),
                ),
                Expanded(child: body),
                if (showBottomNav)
                  TapTalkBottomNav(
                    current: currentRoute,
                    onMicTap: onMicTap,
                    micActive: micActive,
                  ),
              ],
            ),
            const SourceDrawer(),
          ],
        ),
    );
  }
}
