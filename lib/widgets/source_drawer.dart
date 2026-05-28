import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';

class SourceDrawer extends StatelessWidget {
  const SourceDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;

    if (!app.drawerOpen) return const SizedBox.shrink();

    return Stack(
      children: [
        GestureDetector(
          onTap: () => app.toggleDrawer(false),
          child: Container(color: Colors.black.withValues(alpha: 0.18)),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Material(
            elevation: 12,
            color: theme.bgMid,
            child: SizedBox(
              width: 228,
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
                      _DrawerItem(
                        icon: Icons.school_outlined,
                        label: AppStrings.classes(lang),
                        onTap: () {},
                      ),
                      _DrawerItem(
                        icon: Icons.person_outline,
                        label: AppStrings.forMe(lang),
                        active: true,
                        onTap: () => app.toggleDrawer(false),
                      ),
                      const Spacer(),
                      _DrawerItem(
                        icon: Icons.logout_rounded,
                        label: AppStrings.logout(lang),
                        centered: true,
                        onTap: () => app.logout(),
                      ),
                    ],
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
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.centered = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppState>().theme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: active
            ? Colors.white.withValues(alpha: 0.22)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              mainAxisAlignment:
                  centered ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: active
                        ? theme.bgAccent.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(icon, color: theme.textMain, size: 19),
                ),
                if (!centered) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      color: theme.textMain,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
