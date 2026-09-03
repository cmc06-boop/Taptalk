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

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Consumer<AppState>(
        builder: (ctx, liveApp, _) {
          final liveEmail = AuthValidation.normalizeEmail(
            liveApp.user?.email ?? '',
          );
          return SafeArea(
            child: _AccountSheetChrome(
              theme: theme,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
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
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Tooltip(
                        message: AppStrings.manageAccounts(lang),
                        child: Material(
                          color: theme.bgMid.withValues(alpha: 0.55),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => ManageAccountsSheet.show(ctx),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.manage_accounts_outlined,
                                size: 20,
                                color: theme.textMain.withValues(alpha: 0.72),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (liveApp.savedAccounts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
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
                    for (final account in liveApp.savedAccounts)
                      _AccountTile(
                        account: account,
                        theme: theme,
                        lang: lang,
                        isCurrent: account.email == liveEmail,
                        onTap: account.email == liveEmail
                            ? null
                            : () async {
                                Navigator.pop(ctx);
                                await liveApp.prepareSwitchToAccount(
                                  account.email,
                                );
                              },
                      ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await liveApp.prepareAddAccount();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.bgAccent,
                      side: BorderSide(
                        color: theme.bgAccent.withValues(alpha: 0.45),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
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
          );
        },
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
    final initials = _accountInitials(account.displayName, account.email);
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

}

String _accountInitials(String name, String email) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2 && parts.first.isNotEmpty && parts.last.isNotEmpty) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  if (name.trim().isNotEmpty) return name.trim()[0].toUpperCase();
  if (email.isNotEmpty) return email[0].toUpperCase();
  return '?';
}

class _AccountSheetChrome extends StatelessWidget {
  const _AccountSheetChrome({
    required this.theme,
    required this.child,
  });

  final TapTalkThemeToken theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: child,
    );
  }
}

abstract final class ManageAccountsSheet {
  static Future<void> show(BuildContext switchContext) async {
    final app = switchContext.read<AppState>();
    await app.refreshSavedAccounts();
    if (!switchContext.mounted) return;

    final theme = app.theme;
    final lang = app.language;

    await showModalBottomSheet<void>(
      context: switchContext,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Consumer<AppState>(
        builder: (ctx, liveApp, _) {
          final liveEmail = AuthValidation.normalizeEmail(
            liveApp.user?.email ?? '',
          );
          return SafeArea(
            child: _AccountSheetChrome(
              theme: theme,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.72,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppStrings.manageAccounts(lang),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: theme.textMain,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      AppStrings.manageAccountsSubtitle(lang),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: theme.textMain.withValues(alpha: 0.65),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Flexible(
                      child: liveApp.savedAccounts.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.md,
                              ),
                              child: Text(
                                AppStrings.switchAccountEmpty(lang),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: theme.textMain.withValues(alpha: 0.7),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: liveApp.savedAccounts.length,
                              itemBuilder: (_, index) {
                                final account = liveApp.savedAccounts[index];
                                return _ManageAccountTile(
                                  account: account,
                                  theme: theme,
                                  lang: lang,
                                  isCurrent: account.email == liveEmail,
                                  onRemove: () => _confirmRemove(
                                    manageContext: ctx,
                                    switchContext: switchContext,
                                    app: liveApp,
                                    account: account,
                                    isCurrent: account.email == liveEmail,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static Future<void> _confirmRemove({
    required BuildContext manageContext,
    required BuildContext switchContext,
    required AppState app,
    required SavedAccount account,
    required bool isCurrent,
  }) async {
    final lang = app.language;
    final theme = app.theme;
    final confirmed = await showDialog<bool>(
      context: manageContext,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          AppStrings.removeAccountConfirmTitle(lang),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: theme.textMain,
          ),
        ),
        content: Text(
          AppStrings.removeAccountConfirmMessage(lang),
          style: GoogleFonts.poppins(
            fontSize: 13,
            height: 1.4,
            color: theme.textMain.withValues(alpha: 0.75),
          ),
        ),
        actionsAlignment: MainAxisAlignment.end,
        actionsOverflowButtonSpacing: 0,
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: Text(
                    AppStrings.cancel(lang),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    AppStrings.removeFromThisDevice(lang),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (isCurrent) {
      if (manageContext.mounted) Navigator.pop(manageContext);
      if (switchContext.mounted) Navigator.pop(switchContext);
    }
    await app.removeSavedAccountFromThisDevice(account.email);
  }
}

class _ManageAccountTile extends StatelessWidget {
  const _ManageAccountTile({
    required this.account,
    required this.theme,
    required this.lang,
    required this.isCurrent,
    required this.onRemove,
  });

  final SavedAccount account;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final bool isCurrent;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final initials = _accountInitials(account.displayName, account.email);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: Container(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                          account.email,
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
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.xs),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: theme.bgAccent,
                        size: 20,
                      ),
                    ),
                ],
              ),
              TextButton(
                onPressed: onRemove,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFC62828),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.centerLeft,
                ),
                child: Text(
                  AppStrings.removeFromThisDevice(lang),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
