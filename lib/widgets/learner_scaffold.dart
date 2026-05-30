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
    this.showBackButton = false,
    this.onBack,
  });

  final String title;
  final Widget body;
  final AppRoute currentRoute;
  final VoidCallback? onMicTap;
  final bool micActive;
  final bool showBottomNav;
  final bool showBackButton;
  final VoidCallback? onBack;

  bool _forMeShowsBottomNav(AppRoute route) {
    return route == AppRoute.home ||
        route == AppRoute.favorites ||
        route == AppRoute.history ||
        route == AppRoute.settings;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isParent = app.user?.isParent ?? false;
    final isTeacher = app.user?.isTeacher ?? false;
    final forMeOnlyNav = isParent || isTeacher;
    final effectiveShowBottomNav =
        showBottomNav && (!forMeOnlyNav || _forMeShowsBottomNav(currentRoute));

    return TapTalkShell(
      child: Stack(
        children: [
            Column(
              children: [
                AppHeader(
                  title: title,
                  showBackButton: showBackButton,
                  onBack: onBack,
                  onMenu: showBackButton ? null : () => app.toggleDrawer(),
                  showProfile:
                      !isParent && !isTeacher && !showBackButton,
                  showAlerts: isTeacher && !showBackButton,
                  showNotifications: isParent && !showBackButton,
                  notificationBadgeCount: app.unreadNotificationCount,
                  onNotifications: () => app.setRoute(AppRoute.notifications),
                  onAlerts: () => app.setRoute(AppRoute.teacherMonitoring),
                  onProfile: () => app.setRoute(AppRoute.profile),
                ),
                Expanded(child: body),
                if (effectiveShowBottomNav)
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
