import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';

/// Dialog for teachers to create a class (e.g. "English 1-Sampaguita").
class CreateClassDialog extends StatefulWidget {
  const CreateClassDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => const CreateClassDialog(),
    );
  }

  @override
  State<CreateClassDialog> createState() => _CreateClassDialogState();
}

class _CreateClassDialogState extends State<CreateClassDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final app = context.read<AppState>();
    final lang = app.language;
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = AppStrings.enterClassName(lang));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await app.createTeacherClass(name);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        AppStrings.createClass(lang),
        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.createClassHint(lang),
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: theme.textMain.withValues(alpha: 0.65),
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: AppStrings.classNameExample(lang),
              errorText: _error,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
            ),
            onSubmitted: (_) => _busy ? null : _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(AppStrings.cancel(lang)),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: theme.bgAccent),
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
                  AppStrings.create(lang),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                ),
        ),
      ],
    );
  }
}
