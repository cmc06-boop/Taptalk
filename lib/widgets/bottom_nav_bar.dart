import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';

class TapTalkBottomNav extends StatelessWidget {
  const TapTalkBottomNav({
    super.key,
    required this.current,
    this.onMicTap,
    this.micActive = false,
  });

  final AppRoute current;
  final VoidCallback? onMicTap;
  final bool micActive;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;

    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.lg + bottomInset,
      ),
      decoration: BoxDecoration(
        color: theme.bgMid,
        boxShadow: [
          BoxShadow(
            color: theme.bgAccent.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _NavItem(
              icon: Icons.home_rounded,
              label: AppStrings.home(lang),
              active: current == AppRoute.home,
              onTap: () => app.setRoute(AppRoute.home),
              color: theme,
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.favorite_border_rounded,
              label: AppStrings.favorites(lang),
              active: current == AppRoute.favorites,
              onTap: () => app.setRoute(AppRoute.favorites),
              color: theme,
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -18),
            child: Material(
              color: micActive ? Colors.red : theme.bgAccent,
              shape: const CircleBorder(),
              elevation: 8,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onMicTap,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.92),
                      width: 4,
                    ),
                  ),
                  child: const Icon(Icons.mic_rounded, color: Colors.white, size: 28),
                ),
              ),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.history_rounded,
              label: AppStrings.history(lang),
              active: current == AppRoute.history,
              onTap: () => app.setRoute(AppRoute.history),
              color: theme,
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.settings_outlined,
              label: AppStrings.settings(lang),
              active: current == AppRoute.settings,
              onTap: () => app.setRoute(AppRoute.settings),
              color: theme,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final dynamic color;

  @override
  Widget build(BuildContext context) {
    final theme = color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: active ? theme.bgAccent : theme.textMain.withValues(alpha: 0.68),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active ? theme.bgAccent : theme.textMain.withValues(alpha: 0.68),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
