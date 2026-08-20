import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../providers/app_state.dart';
import 'app_header.dart';
import 'bottom_nav_bar.dart';
import 'source_drawer.dart';
import 'taptalk_shell.dart';

class LearnerScaffold extends StatelessWidget {
  const LearnerScaffold({
    super.key,
    required this.title,
    this.titleBadge,
    this.titleWidget,
    required this.body,
    required this.currentRoute,
    this.onMicTap,
    this.micActive = false,
    this.showBottomNav = true,
    this.headerTrailing,
    this.headerBottomSpacing = AppSpacing.md,
    this.bodyTopOffset = 0,
    this.headerContentHeight,
  });

  final String title;
  final Widget? titleBadge;
  final Widget? titleWidget;
  final Widget body;
  final AppRoute currentRoute;
  final VoidCallback? onMicTap;
  final bool micActive;
  final bool showBottomNav;
  final Widget? headerTrailing;
  final double headerBottomSpacing;
  final double bodyTopOffset;
  final double? headerContentHeight;

  bool _forMeShowsBottomNav(AppRoute route) {
    return route == AppRoute.home ||
        route == AppRoute.favorites ||
        route == AppRoute.history ||
        route == AppRoute.settings ||
        route == AppRoute.chooseCategory;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isParent = app.user?.isParent ?? false;
    final isTeacher = app.user?.isTeacher ?? false;
    final forMeOnlyNav = isParent || isTeacher;
    final effectiveShowBottomNav =
        showBottomNav && (!forMeOnlyNav || _forMeShowsBottomNav(currentRoute));

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return TapTalkShell(
      child: Stack(
        children: [
          Column(
            children: [
              AppHeader(
                title: title,
                titleBadge: titleBadge,
                titleWidget: titleWidget,
                onMenu: () => app.toggleDrawer(),
                trailingAction: headerTrailing,
                showProfile: !isParent && !isTeacher,
                showAlerts: isTeacher,
                showNotifications: isParent,
                notificationBadgeCount: app.unreadNotificationCount,
                bottomSpacing: headerBottomSpacing,
                contentHeight: headerContentHeight,
                onNotifications: () => app.setRoute(AppRoute.notifications),
                onAlerts: () => app.setRoute(AppRoute.teacherMonitoring),
                onProfile: () => app.setRoute(AppRoute.profile),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: effectiveShowBottomNav ? 0 : bottomInset,
                  ),
                  child: Transform.translate(
                    offset: Offset(0, bodyTopOffset),
                    child: KeyedSubtree(
                      key: ValueKey(
                        'body_${app.language.name}_${app.languageRevision}',
                      ),
                      child: body,
                    ),
                  ),
                ),
              ),
              if (effectiveShowBottomNav)
                TapTalkBottomNav(
                  current: currentRoute,
                  onMicTap: onMicTap,
                  micActive: micActive,
                ),
            ],
          ),
          Positioned.fill(child: const SourceDrawer()),
        ],
      ),
    );
  }
}
