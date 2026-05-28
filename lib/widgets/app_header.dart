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
    this.onProfile,
    this.showProfile = true,
  });

  final String title;
  final VoidCallback? onMenu;
  final VoidCallback? onProfile;
  final bool showProfile;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppState>().theme;

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
            icon: Icons.menu_rounded,
            onTap: onMenu,
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
          if (showProfile)
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
          : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
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
