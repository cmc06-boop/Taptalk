import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../providers/app_state.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.onMenu,
    this.onBack,
    this.onProfile,
    this.onNotifications,
    this.onAlerts,
    this.showProfile = true,
    this.showNotifications = false,
    this.showAlerts = false,
    this.showBackButton = false,
    this.notificationBadgeCount = 0,
  });

  final String title;
  final VoidCallback? onMenu;
  final VoidCallback? onBack;
  final VoidCallback? onProfile;
  final VoidCallback? onNotifications;
  final VoidCallback? onAlerts;
  final bool showProfile;
  final bool showNotifications;
  final bool showAlerts;
  final bool showBackButton;
  final int notificationBadgeCount;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          _CircleIconButton(
            icon: showBackButton ? Icons.arrow_back_rounded : Icons.menu_rounded,
            onTap: showBackButton
                ? (onBack ?? () => Navigator.maybePop(context))
                : onMenu,
            accent: theme.bgAccent,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: theme.textMain,
              ),
            ),
          ),
          if (showNotifications)
            Stack(
              clipBehavior: Clip.none,
              children: [
                _CircleIconButton(
                  icon: Icons.notifications_outlined,
                  onTap: onNotifications ??
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
              onTap: onAlerts ??
                  () => app.setRoute(AppRoute.teacherMonitoring),
              accent: theme.bgAccent,
              filled: true,
            )
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
          ? Color.alphaBlend(
              Colors.white.withValues(alpha: 0.55),
              accent,
            )
          : Colors.white.withValues(alpha: 0.22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 22,
            color: filled ? Colors.white : accent,
          ),
        ),
      ),
    );
  }
}
