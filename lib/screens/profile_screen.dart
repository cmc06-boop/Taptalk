import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../providers/app_state.dart';
import '../widgets/learner_scaffold.dart';
import '../widgets/panel_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  String _savedName = '';
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _syncFromUser(AppState app) {
    final name = app.user?.fullName ?? '';
    if (_savedName == name) return;
    _savedName = name;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_nameController.text != name) {
        _nameController.text = name;
      }
    });
  }

  bool get _hasChanges => _nameController.text.trim() != _savedName.trim();

  void _cancelEdits() {
    _nameController.text = _savedName;
    setState(() {});
  }

  Future<void> _save(AppState app, AppLanguage lang) async {
    setState(() => _saving = true);
    final err = await app.updateProfileName(_nameController.text);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    _savedName = _nameController.text.trim();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.profileUpdated(lang))),
    );
    setState(() {});
  }

  Future<void> _showEditPassword(AppState app, AppLanguage lang) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => _EditPasswordDialog(app: app, lang: lang),
    );
    if (!mounted || updated != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.passwordUpdated(lang))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.user;
    final lang = app.language;
    final theme = app.theme;

    _syncFromUser(app);

    return LearnerScaffold(
      title: AppStrings.appName(lang),
      currentRoute: AppRoute.profile,
      showBottomNav: true,
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.myProfile(lang),
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: theme.textMain,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppStrings.profileSubtitle(lang),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: theme.textMain.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          PanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.personalDetails(lang),
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: theme.textMain,
                        ),
                      ),
                    ),
                    if (_hasChanges)
                      TextButton(
                        onPressed: _cancelEdits,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: theme.textMain,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                        ),
                        child: Text(
                          AppStrings.cancel(lang),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _ProfileField(
                  label: AppStrings.fullName(lang),
                  controller: _nameController,
                  theme: theme,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.md),
                _ProfileReadOnlyValue(
                  label: AppStrings.emailAddress(lang),
                  value: user?.email ?? '',
                  theme: theme,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  AppStrings.profileCode(lang),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: theme.textMain.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        app.profileCode,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: theme.textMain,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: app.profileCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppStrings.copied(lang))),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.bgAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                      ),
                      child: Text(
                        AppStrings.copy(lang),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.profileCodeHint(lang),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: theme.textMain.withValues(alpha: 0.62),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: !_hasChanges || _saving ? null : () => _save(app, lang),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.bgAccent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          AppStrings.saveChanges(lang),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ],
            ),
          ),
          PanelCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Text(
                  AppStrings.password(lang),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.textMain,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _showEditPassword(app, lang),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: theme.textMain,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                  ),
                  child: Text(
                    AppStrings.editPassword(lang),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditPasswordDialog extends StatefulWidget {
  const _EditPasswordDialog({required this.app, required this.lang});

  final AppState app;
  final AppLanguage lang;

  @override
  State<_EditPasswordDialog> createState() => _EditPasswordDialogState();
}

class _EditPasswordDialogState extends State<_EditPasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _obscureCurrent = true;
  bool _obscureNext = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final lang = widget.lang;
    if (_current.text.isEmpty || _next.text.isEmpty || _confirm.text.isEmpty) {
      setState(() => _error = AppStrings.fillAllFields(lang));
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = AppStrings.passwordsDoNotMatch(lang));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.app.changePassword(_current.text, _next.text);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final theme = widget.app.theme;

    return AlertDialog(
      title: Text(AppStrings.editPassword(lang)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ProfileField(
                label: AppStrings.currentPassword(lang),
                controller: _current,
                theme: theme,
                obscure: _obscureCurrent,
                onToggleObscure: () =>
                    setState(() => _obscureCurrent = !_obscureCurrent),
              ),
              const SizedBox(height: AppSpacing.sm),
              _ProfileField(
                label: AppStrings.newPassword(lang),
                controller: _next,
                theme: theme,
                obscure: _obscureNext,
                onToggleObscure: () => setState(() => _obscureNext = !_obscureNext),
              ),
              const SizedBox(height: AppSpacing.sm),
              _ProfileField(
                label: AppStrings.confirmPassword(lang),
                controller: _confirm,
                theme: theme,
                obscure: _obscureConfirm,
                onToggleObscure: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(AppStrings.cancel(lang)),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppStrings.saveChanges(lang)),
        ),
      ],
    );
  }
}

class _ProfileReadOnlyValue extends StatelessWidget {
  const _ProfileReadOnlyValue({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String value;
  final TapTalkThemeToken theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.textMain.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.textMain,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.controller,
    required this.theme,
    this.obscure = false,
    this.onToggleObscure,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final TapTalkThemeToken theme;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.textMain.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          obscureText: obscure,
          onChanged: onChanged,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: theme.textMain,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: theme.textMain.withValues(alpha: 0.55),
                    ),
                    onPressed: onToggleObscure,
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
