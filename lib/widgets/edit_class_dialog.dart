import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';

class EditClassDialog extends StatefulWidget {
  const EditClassDialog({
    super.key,
    required this.classId,
    required this.initialName,
  });

  final int classId;
  final String initialName;

  static Future<bool?> show(
    BuildContext context, {
    required int classId,
    required String initialName,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => EditClassDialog(
        classId: classId,
        initialName: initialName,
      ),
    );
  }

  @override
  State<EditClassDialog> createState() => _EditClassDialogState();
}

class _EditClassDialogState extends State<EditClassDialog> {
  late final TextEditingController _controller;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

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
    final ok = await app.updateTeacherClassName(widget.classId, name);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _error = AppStrings.enterClassName(lang);
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
        AppStrings.editClass(lang),
        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
      ),
      content: TextField(
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
                  AppStrings.saveChanges(lang),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                ),
        ),
      ],
    );
  }
}

