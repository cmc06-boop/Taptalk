import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';
import 'taptalk_result_dialog.dart';

/// Parent enters a child's profile code to link accounts.
class LinkChildDialog extends StatefulWidget {
  const LinkChildDialog({super.key});

  /// Returns `true` after a successful link, or null if cancelled.
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const LinkChildDialog(),
    );
  }

  @override
  State<LinkChildDialog> createState() => _LinkChildDialogState();
}

class _LinkChildDialogState extends State<LinkChildDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;

    final app = context.read<AppState>();
    final lang = app.language;
    final code = _controller.text.trim();

    if (code.isEmpty) {
      setState(() => _error = AppStrings.fillAllFields(lang));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final error = await app.linkChildByProfileCode(code);
    if (!mounted) return;

    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }

    if (!mounted) return;
    final rootNav = Navigator.of(context, rootNavigator: true);
    final rootContext = rootNav.context;
    rootNav.pop(true);
    if (!rootContext.mounted) return;
    await TapTalkResultDialog.showSuccess(
      rootContext,
      title: AppStrings.childLinkedTitle(lang),
      message: AppStrings.childLinked(lang),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.language;
    final theme = app.theme;

    return TapTalkDialogShell(
      theme: theme,
      title: AppStrings.linkChildCode(lang),
      message: AppStrings.enterChildCodeHint(lang),
      showMessage: false,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.enterChildCodeHint(lang),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: theme.textMain.withValues(alpha: 0.72),
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            enabled: !_busy,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'TT-XXXXXXXX',
              filled: true,
              fillColor: TapTalkDialogShell.sheetFill,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: TapTalkDialogShell.fieldBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: TapTalkDialogShell.fieldBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: theme.bgAccent.withValues(alpha: 0.7),
                  width: 1.6,
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: TapTalkDialogShell.errorIcon,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(
            AppStrings.cancel(lang),
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  AppStrings.add(lang),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                ),
        ),
      ],
    );
  }
}
