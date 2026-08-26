import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../providers/app_state.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.titleBadge,
    this.titleWidget,
    this.onMenu,
    this.onProfile,
    this.onNotifications,
    this.onAlerts,
    this.showProfile = true,
    this.showNotifications = false,
    this.showAlerts = false,
    this.notificationBadgeCount = 0,
    this.trailingAction,
    this.bottomSpacing = AppSpacing.md,
    this.contentHeight,
  });

  final String title;
  final Widget? titleBadge;
  final Widget? titleWidget;
  final VoidCallback? onMenu;
  final VoidCallback? onProfile;
  final VoidCallback? onNotifications;
  final VoidCallback? onAlerts;
  final bool showProfile;
  final bool showNotifications;
  final bool showAlerts;
  final int notificationBadgeCount;
  final Widget? trailingAction;
  final double bottomSpacing;
  final double? contentHeight;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;

    final topInset = MediaQuery.paddingOf(context).top;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm + topInset,
        AppSpacing.lg,
        bottomSpacing,
      ),
      child: SizedBox(
        height: contentHeight,
        child: Row(
          children: [
            if (onMenu != null)
              _CircleIconButton(
                icon: Icons.menu_rounded,
                onTap: onMenu,
                accent: theme.bgAccent,
              )
            else
              const SizedBox(width: 36),
            Expanded(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child:
                          titleWidget ??
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: theme.textMain,
                            ),
                          ),
                    ),
                    if (titleBadge != null) ...[
                      const SizedBox(width: 8),
                      titleBadge!,
                    ],
                  ],
                ),
              ),
            ),
            if (showNotifications)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _CircleIconButton(
                    icon: Icons.notifications_outlined,
                    onTap:
                        onNotifications ??
                        () => app.setRoute(AppRoute.notifications),
                    accent: theme.bgAccent,
                    filled: true,
                  ),
                  if (notificationBadgeCount > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: theme.bgLight, width: 2),
                        ),
                        child: Text(
                          notificationBadgeCount > 9
                              ? '9+'
                              : '$notificationBadgeCount',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              )
            else if (showAlerts)
              _CircleIconButton(
                icon: Icons.campaign_outlined,
                onTap:
                    onAlerts ?? () => app.setRoute(AppRoute.teacherMonitoring),
                accent: theme.bgAccent,
                filled: true,
              )
            else if (trailingAction != null)
              trailingAction!
            else if (showProfile)
              _CircleIconButton(
                icon: Icons.person_outline_rounded,
                onTap: onProfile,
                accent: theme.bgAccent,
                filled: true,
              )
            else
              const SizedBox(width: 36),
          ],
        ),
      ),
    );
  }
}

/// Page name for [AppHeader.titleWidget], sized to the same 85px block the
/// branded wordmark occupies so every page's body starts at the same height.
class AppHeaderTitle extends StatelessWidget {
  const AppHeaderTitle(this.label, {super.key});

  static const double height = 85;

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppState>().theme;
    return SizedBox(
      height: height,
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: theme.textMain,
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.accent,
    this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled
          ? Color.alphaBlend(Colors.white.withValues(alpha: 0.55), accent)
          : Colors.white.withValues(alpha: 0.22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 22, color: filled ? Colors.white : accent),
        ),
      ),
    );
  }
}
