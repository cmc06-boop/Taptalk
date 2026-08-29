import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../core/utils/auth_validation.dart';
import '../data/models/saved_account.dart';
import '../providers/app_state.dart';

abstract final class SwitchAccountSheet {
  static Future<void> show(BuildContext context) async {
    final app = context.read<AppState>();
    app.toggleDrawer(false);
    await app.refreshSavedAccounts();
    if (!context.mounted) return;

    final theme = app.theme;
    final lang = app.language;
    final currentEmail = AuthValidation.normalizeEmail(app.user?.email ?? '');

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE7EDF2)),
            boxShadow: [
              BoxShadow(
                color: theme.textMain.withValues(alpha: 0.12),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.switchAccountTitle(lang),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: theme.textMain,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppStrings.switchAccountSubtitle(lang),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: theme.textMain.withValues(alpha: 0.65),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (app.savedAccounts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(
                    AppStrings.switchAccountEmpty(lang),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: theme.textMain.withValues(alpha: 0.7),
                    ),
                  ),
                )
              else
                for (final account in app.savedAccounts)
                  _AccountTile(
                    account: account,
                    theme: theme,
                    lang: lang,
                    isCurrent: account.email == currentEmail,
                    onTap: account.email == currentEmail
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            await app.prepareSwitchToAccount(account.email);
                          },
                  ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await app.prepareAddAccount();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.bgAccent,
                  side: BorderSide(color: theme.bgAccent.withValues(alpha: 0.45)),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
                label: Text(
                  AppStrings.addAnotherAccount(lang),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.theme,
    required this.lang,
    required this.isCurrent,
    required this.onTap,
  });

  final SavedAccount account;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(account.displayName, account.email);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isCurrent
                  ? theme.bgAccent.withValues(alpha: 0.1)
                  : theme.bgMid.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCurrent
                    ? theme.bgAccent.withValues(alpha: 0.35)
                    : const Color(0xFFE9EEF2),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.bgAccent.withValues(alpha: 0.18),
                  child: Text(
                    initials,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      color: theme.bgAccent,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.displayName.isNotEmpty
                            ? account.displayName
                            : account.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: theme.textMain,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${AppStrings.accountRoleLabel(lang, account.role)} · ${account.email}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: theme.textMain.withValues(alpha: 0.62),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Icon(Icons.check_circle_rounded, color: theme.bgAccent, size: 22)
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.textMain.withValues(alpha: 0.35),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _initials(String name, String email) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts.first.isNotEmpty && parts.last.isNotEmpty) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    if (name.trim().isNotEmpty) return name.trim()[0].toUpperCase();
    if (email.isNotEmpty) return email[0].toUpperCase();
    return '?';
  }
}
