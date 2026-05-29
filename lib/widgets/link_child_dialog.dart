import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';

/// Parent enters a child's profile code to link accounts.
/// Owns its [TextEditingController] and performs linking before closing.
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

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final lang = app.language;
    final theme = app.theme;

    return AlertDialog(
      title: Text(
        AppStrings.linkChildCode(lang),
        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              enabled: !_busy,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                hintText: AppStrings.enterChildCodeHint(lang),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFFC62828),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(AppStrings.cancel(lang)),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: theme.bgAccent,
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
              : Text(AppStrings.add(lang)),
        ),
      ],
    );
  }
}
