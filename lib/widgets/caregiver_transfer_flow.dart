import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/l10n/app_strings.dart';
import '../data/models/linked_child_model.dart';
import '../providers/app_state.dart';
import '../services/caregiver_security_service.dart';
import 'code_qr_sheet.dart';
import 'security_step_layout.dart';
import 'taptalk_result_dialog.dart';

/// Moving one learner between two caregiver accounts. The current caregiver
/// reauthenticates and creates the offer; the new caregiver scans it.
class CaregiverTransferFlow {
  CaregiverTransferFlow._();

  static Future<void> create(
    BuildContext context,
    LinkedChildModel child,
  ) async {
    final code = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (_) => _CreateTransferDialog(child: child),
    );
    if (code == null || !context.mounted) return;
    final lang = context.read<AppState>().language;
    await CodeQrSheet.show(
      context,
      title: AppStrings.transferCodeTitle(lang),
      code: code,
      subtitle: AppStrings.transferCodeHint(lang),
      shareMessage: AppStrings.shareTransferCodeMessage(lang, code),
    );
  }
}

class _CreateTransferDialog extends StatefulWidget {
  const _CreateTransferDialog({required this.child});

  final LinkedChildModel child;

  @override
  State<_CreateTransferDialog> createState() => _CreateTransferDialogState();
}

class _CreateTransferDialogState extends State<_CreateTransferDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _password.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _create({bool google = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await context.read<AppState>().requestCaregiverTransfer(
      learnerId: widget.child.learnerId,
      password: google ? null : _password.text,
      google: google,
    );
    if (!mounted) return;
    if (result.requestId != null) {
      Navigator.pop(context, result.requestId);
      return;
    }
    setState(() {
      _busy = false;
      _error = result.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.language;
    final theme = app.theme;
    final providers = CaregiverSecurityService.instance.recoveryProviders;
    final hasPassword = providers.contains('password');
    final hasGoogle = providers.contains('google.com');
    return TapTalkDialogShell(
      theme: theme,
      title: AppStrings.transferLearnerTitle(lang, widget.child.fullName),
      message: '',
      icon: Icon(Icons.lock_outline_rounded, size: 30, color: theme.bgAccent),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppStrings.transferLearnerBody(lang),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: theme.textMain.withValues(alpha: 0.72),
              height: 1.45,
            ),
          ),
          if (hasPassword) ...[
            const SizedBox(height: 16),
            SecurityStepField(
              controller: _password,
              label: AppStrings.confirmAccountPassword(lang),
              obscure: true,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: TapTalkDialogShell.errorIcon,
              ),
            ),
          ],
        ],
      ),
      actions: [
        _ActionStack(
          children: [
            _PrimaryButton(
              label: hasPassword
                  ? AppStrings.createTransferCode(lang)
                  : AppStrings.confirmWithGoogle(lang),
              busy: _busy,
              onPressed: _busy || (hasPassword && _password.text.isEmpty)
                  ? null
                  : () => _create(google: !hasPassword),
            ),
            if (hasPassword && hasGoogle)
              _SecondaryButton(
                label: AppStrings.confirmWithGoogle(lang),
                onPressed: _busy ? null : () => _create(google: true),
              ),
            _SecondaryButton(
              label: AppStrings.cancel(lang),
              onPressed: _busy ? null : () => Navigator.pop(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionStack extends StatelessWidget {
  const _ActionStack({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.black.withValues(alpha: 0.6),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppState>().theme;
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: theme.textMain.withValues(alpha: 0.7),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
