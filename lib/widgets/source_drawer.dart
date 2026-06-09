import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../providers/app_state.dart';

bool _isForMeRoute(AppRoute route) {
  return route == AppRoute.home ||
      route == AppRoute.favorites ||
      route == AppRoute.history ||
      route == AppRoute.settings;
}

Widget _settingsDrawerItem({
  required TapTalkThemeToken theme,
  required AppLanguage lang,
  required AppState app,
}) {
  return _DrawerItem(
    theme: theme,
    icon: Icons.settings_outlined,
    label: AppStrings.settings(lang),
    active: app.route == AppRoute.settings,
    onTap: () => app.setRoute(AppRoute.settings),
  );
}

class SourceDrawer extends StatelessWidget {
  const SourceDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;

    return Stack(
      children: [
        IgnorePointer(
          ignoring: !app.drawerOpen,
          child: AnimatedOpacity(
            duration: AppSpacing.drawerAnimation,
            curve: Curves.easeOutCubic,
            opacity: app.drawerOpen ? 1 : 0,
            child: GestureDetector(
              onTap: () => app.toggleDrawer(false),
              child: Container(color: Colors.black.withValues(alpha: 0.18)),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: IgnorePointer(
            ignoring: !app.drawerOpen,
            child: AnimatedSlide(
              duration: AppSpacing.drawerAnimation,
              curve: Curves.easeOutCubic,
              offset: app.drawerOpen ? Offset.zero : const Offset(-1.04, 0),
              child: AnimatedOpacity(
                duration: AppSpacing.drawerAnimation,
                curve: Curves.easeOutCubic,
                opacity: app.drawerOpen ? 1 : 0,
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height,
                  width: 238,
                  child: Container(
                  decoration: BoxDecoration(
                    color: theme.bgMid,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.textMain.withValues(alpha: 0.20),
                        blurRadius: 24,
                        offset: const Offset(8, 0),
                      ),
                      BoxShadow(
                        color: theme.bgAccent.withValues(alpha: 0.10),
                        blurRadius: 30,
                        offset: const Offset(10, 0),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'TapTalk',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: theme.textMain,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            AppStrings.sources(lang).toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: theme.textMain.withValues(alpha: 0.52),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (app.user?.isParent ?? false) ...[
                            _DrawerItem(
                              theme: theme,
                              icon: Icons.person_outline,
                              label: AppStrings.forMe(lang),
                              active: _isForMeRoute(app.route),
                              onTap: () => app.setRoute(AppRoute.home),
                            ),
                            _DrawerItem(
                              theme: theme,
                              icon: Icons.child_care_outlined,
                              label: AppStrings.myChild(lang),
                              active: app.route == AppRoute.myChild,
                              onTap: () => app.setRoute(AppRoute.myChild),
                            ),
                            _DrawerItem(
                              theme: theme,
                              icon: Icons.person_outline_rounded,
                              label: AppStrings.profile(lang),
                              active: app.route == AppRoute.profile,
                              onTap: () => app.setRoute(AppRoute.profile),
                            ),
                            _settingsDrawerItem(
                              theme: theme,
                              lang: lang,
                              app: app,
                            ),
                          ] else if (app.user?.isLearner ?? false) ...[
                            _DrawerItem(
                              theme: theme,
                              icon: Icons.person_outline,
                              label: AppStrings.forMe(lang),
                              active: _isForMeRoute(app.route),
                              onTap: () => app.setRoute(AppRoute.home),
                            ),
                            _DrawerItem(
                              theme: theme,
                              icon: Icons.school_outlined,
                              label: AppStrings.classes(lang),
                              active: app.route == AppRoute.classes,
                              onTap: () => app.setRoute(AppRoute.classes),
                            ),
                            _settingsDrawerItem(
                              theme: theme,
                              lang: lang,
                              app: app,
                            ),
                          ] else if (app.user?.isTeacher ?? false) ...[
                            _DrawerItem(
                              theme: theme,
                              icon: Icons.dashboard_outlined,
                              label: AppStrings.dashboard(lang),
                              active: app.route == AppRoute.teacherDashboard,
                              onTap: () =>
                                  app.setRoute(AppRoute.teacherDashboard),
                            ),
                            _DrawerItem(
                              theme: theme,
                              icon: Icons.person_outline,
                              label: AppStrings.forMe(lang),
                              active: _isForMeRoute(app.route),
                              onTap: () => app.setRoute(AppRoute.home),
                            ),
                            _DrawerItem(
                              theme: theme,
                              icon: Icons.class_outlined,
                              label: AppStrings.myClasses(lang),
                              active: app.route == AppRoute.teacherMyClasses,
                              onTap: () =>
                                  app.setRoute(AppRoute.teacherMyClasses),
                            ),
                            _DrawerItem(
                              theme: theme,
                              icon: Icons.monitor_heart_outlined,
                              label: AppStrings.monitoring(lang),
                              active: app.route == AppRoute.teacherMonitoring,
                              onTap: () =>
                                  app.setRoute(AppRoute.teacherMonitoring),
                            ),
                            _DrawerItem(
                              theme: theme,
                              icon: Icons.person_outline_rounded,
                              label: AppStrings.profile(lang),
                              active: app.route == AppRoute.profile,
                              onTap: () => app.setRoute(AppRoute.profile),
                            ),
                            _settingsDrawerItem(
                              theme: theme,
                              lang: lang,
                              app: app,
                            ),
                          ] else ...[
                            _DrawerItem(
                              theme: theme,
                              icon: Icons.person_outline_rounded,
                              label: AppStrings.profile(lang),
                              active: app.route == AppRoute.profile,
                              onTap: () => app.setRoute(AppRoute.profile),
                            ),
                            _settingsDrawerItem(
                              theme: theme,
                              lang: lang,
                              app: app,
                            ),
                          ],
                          const Spacer(),
                          _DrawerItem(
                            theme: theme,
                            icon: Icons.logout_rounded,
                            label: AppStrings.logout(lang),
                            onTap: app.logout,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.theme,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final TapTalkThemeToken theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final accent = theme.bgAccent;
    final accentStrong = theme.accentEmphasis;
    final textColor = active ? accentStrong : theme.textMain.withValues(alpha: 0.78);
    final iconBg = active
        ? Color.lerp(Colors.white, accent, 0.48)!
        : Colors.white.withValues(alpha: 0.22);
    final rowHighlight = active
        ? Color.lerp(Colors.white, accent, 0.34)!
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: AppSpacing.drawerAnimation,
            curve: Curves.easeOutCubic,
            width: 4,
            height: 40,
            margin: const EdgeInsets.only(right: AppSpacing.sm),
            decoration: BoxDecoration(
              color: active ? accent : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: AnimatedContainer(
                  duration: AppSpacing.drawerAnimation,
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: rowHighlight,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                      color: active
                          ? accent.withValues(alpha: 0.55)
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                          border: active
                              ? Border.all(
                                  color: Colors.white.withValues(alpha: 0.75),
                                )
                              : null,
                        ),
                        child: Icon(
                          icon,
                          color: textColor,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          label,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight:
                                active ? FontWeight.w800 : FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
