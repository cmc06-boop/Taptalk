import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';

class CreateLessonDialog extends StatefulWidget {
  const CreateLessonDialog({super.key, required this.classId});

  final int classId;

  static Future<bool?> show(BuildContext context, {required int classId}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => CreateLessonDialog(classId: classId),
    );
  }

  @override
  State<CreateLessonDialog> createState() => _CreateLessonDialogState();
}

class _CreateLessonDialogState extends State<CreateLessonDialog> {
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
    final title = _controller.text.trim();
    if (title.isEmpty) {
      setState(() => _error = AppStrings.enterLessonTitle(lang));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final lesson = await app.createClassLesson(widget.classId, title);
    if (!mounted) return;
    if (lesson == null) {
      setState(() {
        _busy = false;
        _error = AppStrings.enterLessonTitle(lang);
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
        AppStrings.createLesson(lang),
        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: AppStrings.createLessonHint(lang),
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
                  AppStrings.create(lang),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                ),
        ),
      ],
    );
  }
}
