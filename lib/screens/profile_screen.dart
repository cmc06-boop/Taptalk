import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../core/utils/auth_validation.dart';
import '../data/repositories/app_repository.dart';
import '../providers/app_state.dart';
import '../widgets/learner_scaffold.dart';
import '../widgets/password_strength_hint.dart';
import '../widgets/panel_card.dart';
import '../widgets/taptalk_result_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _emergency1Controller = TextEditingController();
  final _emergency2Controller = TextEditingController();
  String _savedName = '';
  List<String> _savedEmergencyContacts = const [];
  bool _showSecondEmergency = false;
  bool _editing = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emergency1Controller.dispose();
    _emergency2Controller.dispose();
    super.dispose();
  }

  void _syncFromUser(AppState app) {
    final name = app.user?.fullName ?? '';
    final isLearner = app.user?.isLearner ?? false;
    final contacts = isLearner ? app.emergencyContacts : const <String>[];
    if (_savedName == name && _savedEmergencyContacts.join('|') == contacts.join('|')) {
      return;
    }
    _savedName = name;
    _savedEmergencyContacts = List.from(contacts);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_nameController.text != name) {
        _nameController.text = name;
      }
      if (!isLearner) return;
      final first = contacts.isNotEmpty ? contacts.first : '';
      final second = contacts.length > 1 ? contacts[1] : '';
      if (_emergency1Controller.text != first) {
        _emergency1Controller.text = first;
      }
      if (_emergency2Controller.text != second) {
        _emergency2Controller.text = second;
      }
      final shouldShowSecond = second.isNotEmpty;
      if (_showSecondEmergency != shouldShowSecond) {
        setState(() => _showSecondEmergency = shouldShowSecond);
      }
    });
  }

  List<String> get _draftEmergencyContacts {
    final first = _emergency1Controller.text.trim();
    final second = _emergency2Controller.text.trim();
    final raw = <String>[];
    if (first.isNotEmpty) raw.add(first);
    if (_showSecondEmergency && second.isNotEmpty) raw.add(second);
    return AppRepository.normalizeEmergencyContacts(raw);
  }

  bool _canSave(AppState app) {
    final hasName = _nameController.text.trim().isNotEmpty;
    final hasEmail = (app.user?.email ?? '').trim().isNotEmpty;
    if (!(app.user?.isLearner ?? false)) {
      return _editing && !_saving && hasName && hasEmail;
    }
    final hasPrimaryContact = _emergency1Controller.text.trim().isNotEmpty;
    return _editing && !_saving && hasName && hasEmail && hasPrimaryContact;
  }

  void _cancelEdits() {
    _nameController.text = _savedName;
    _emergency1Controller.text = _savedEmergencyContacts.isNotEmpty ? _savedEmergencyContacts[0] : '';
    _emergency2Controller.text = _savedEmergencyContacts.length > 1 ? _savedEmergencyContacts[1] : '';
    _showSecondEmergency = _savedEmergencyContacts.length > 1;
    _editing = false;
    setState(() {});
  }

  Future<void> _save(AppState app, AppLanguage lang) async {
    final name = _nameController.text.trim();
    final email = (app.user?.email ?? '').trim();
    final isLearner = app.user?.isLearner ?? false;
    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.fillAllFields(lang))),
      );
      return;
    }
    if (isLearner && _emergency1Controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.emergencyContactRequired(lang))),
      );
      return;
    }

    final contacts = isLearner ? _draftEmergencyContacts : const <String>[];
    setState(() => _saving = true);
    final err = await app.updateProfileName(_nameController.text);
    if (err == null && isLearner) {
      await app.updateEmergencyContacts(contacts);
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      await TapTalkResultDialog.showError(
        context,
        title: AppStrings.somethingWentWrong(lang),
        message: err,
      );
      return;
    }
    _savedName = _nameController.text.trim();
    if (isLearner) {
      _savedEmergencyContacts = List.from(contacts);
    }
    _editing = false;
    setState(() {});
    await TapTalkResultDialog.showSuccess(
      context,
      title: AppStrings.profileUpdatedTitle(lang),
      message: AppStrings.profileUpdated(lang),
    );
  }

  Future<void> _showEditPassword(AppState app, AppLanguage lang) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => _EditPasswordDialog(app: app, lang: lang),
    );
    if (!mounted || updated != true) return;
    await TapTalkResultDialog.showSuccess(
      context,
      title: AppStrings.passwordUpdatedTitle(lang),
      message: AppStrings.passwordUpdated(lang),
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
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.bgMid.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.myProfile(lang),
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: theme.textMain,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppStrings.profileSubtitle(lang),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: theme.textMain.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
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
                    if (_editing)
                      TextButton(
                        onPressed: _saving ? null : _cancelEdits,
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
                    if (!_editing)
                      TextButton(
                        onPressed: () => setState(() => _editing = true),
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
                          AppStrings.edit(lang),
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
                  enabled: _editing,
                  onChanged: _editing ? (_) => setState(() {}) : null,
                ),
                const SizedBox(height: AppSpacing.md),
                _ProfileReadOnlyValue(
                  label: AppStrings.emailAddress(lang),
                  value: user?.email ?? '',
                  theme: theme,
                ),
                if (user?.isLearner ?? false) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    AppStrings.emergencyContacts(lang),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.textMain.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _ProfileField(
                    label: '',
                    controller: _emergency1Controller,
                    theme: theme,
                    keyboardType: TextInputType.phone,
                    enabled: _editing,
                    showLabel: false,
                    hintText: AppStrings.emergencyContactHint(lang, 1),
                    onChanged: _editing ? (_) => setState(() {}) : null,
                  ),
                  if (_showSecondEmergency) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _ProfileField(
                      label: '',
                      controller: _emergency2Controller,
                      theme: theme,
                      keyboardType: TextInputType.phone,
                      enabled: _editing,
                      showLabel: false,
                      hintText: AppStrings.emergencyContactHint(lang, 2),
                      onChanged: _editing ? (_) => setState(() {}) : null,
                    ),
                  ],
                  if (!_showSecondEmergency)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _editing
                            ? () => setState(() => _showSecondEmergency = true)
                            : null,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text(AppStrings.addAnotherContact(lang)),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.bgAccent,
                          padding: const EdgeInsets.only(top: 6, bottom: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
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
                        onPressed: app.profileCode.isEmpty
                            ? null
                            : () async {
                                await Clipboard.setData(
                                  ClipboardData(text: app.profileCode),
                                );
                                if (!context.mounted) return;
                                await TapTalkResultDialog.showSuccess(
                                  context,
                                  title: AppStrings.copiedTitle(lang),
                                  message: AppStrings.copied(lang),
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
                ],
                const SizedBox(height: AppSpacing.lg),
                if (_editing)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : _cancelEdits,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.textMain,
                            minimumSize: const Size.fromHeight(48),
                            side: BorderSide(
                              color: theme.textMain.withValues(alpha: 0.25),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusMd),
                            ),
                          ),
                          child: Text(
                            AppStrings.cancel(lang),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton(
                          onPressed:
                              _canSave(app) ? () => _save(app, lang) : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.bgAccent,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusMd),
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
                      ),
                    ],
                  )
                else
                  FilledButton(
                    onPressed: null,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.bgAccent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                    ),
                    child: Text(
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
  void initState() {
    super.initState();
    _next.addListener(() => setState(() {}));
  }

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
    if (!AuthValidation.isStrongPassword(_next.text)) {
      setState(() => _error = AppStrings.passwordTooShort(lang));
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
              PasswordStrengthHint(
                password: _next.text,
                lang: lang,
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
              fontWeight: FontWeight.w400,
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
    this.keyboardType,
    this.hintText,
    this.showLabel = true,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final TapTalkThemeToken theme;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final String? hintText;
  final bool showLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.textMain.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        TextField(
          controller: controller,
          enabled: enabled,
          obscureText: obscure,
          onChanged: onChanged,
          keyboardType: keyboardType,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: theme.textMain,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: hintText,
            hintStyle: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: theme.textMain.withValues(alpha: 0.45),
            ),
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
