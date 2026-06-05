import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';

class EditPhraseResult {
  const EditPhraseResult({
    required this.text,
    required this.imagePath,
    required this.clearImage,
  });

  final String text;
  final String? imagePath;
  final bool clearImage;
}

class EditPhraseDialog extends StatefulWidget {
  const EditPhraseDialog({
    super.key,
    required this.initialText,
    required this.initialImagePath,
    this.title,
  });

  final String initialText;
  final String? initialImagePath;
  final String? title;

  static Future<EditPhraseResult?> show(
    BuildContext context, {
    required String initialText,
    required String? initialImagePath,
    String? title,
  }) {
    return showDialog<EditPhraseResult>(
      context: context,
      builder: (_) => EditPhraseDialog(
        initialText: initialText,
        initialImagePath: initialImagePath,
        title: title,
      ),
    );
  }

  @override
  State<EditPhraseDialog> createState() => _EditPhraseDialogState();
}

class _EditPhraseDialogState extends State<EditPhraseDialog> {
  late final TextEditingController _controller;
  String? _imagePath;
  bool _clearImage = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _imagePath = widget.initialImagePath;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 900,
    );
    if (file == null) return;
    setState(() {
      _imagePath = file.path;
      _clearImage = false;
    });
  }

  void _removeImage() {
    setState(() {
      _imagePath = null;
      _clearImage = true;
    });
  }

  void _submit() {
    final app = context.read<AppState>();
    final lang = app.language;
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = AppStrings.enterText(lang));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    Navigator.of(context).pop(
      EditPhraseResult(
        text: text,
        imagePath: _imagePath,
        clearImage: _clearImage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final title = widget.title ?? AppStrings.editPhrase(lang);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        title,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_imagePath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: _imagePath!.toLowerCase().startsWith('assets/')
                    ? Image.asset(
                        _imagePath!,
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                      )
                    : Image.file(
                        File(_imagePath!),
                        width: 96,
                        height: 96,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pickImage,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.bgAccent,
                      side: BorderSide(color: theme.bgAccent.withValues(alpha: 0.45)),
                    ),
                    icon: const Icon(Icons.image_outlined, size: 16),
                    label: Text(AppStrings.attachImage(lang)),
                  ),
                  TextButton.icon(
                    onPressed: _busy ? null : _removeImage,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: Text(AppStrings.remove(lang)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ] else ...[
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickImage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.bgAccent,
                  side: BorderSide(color: theme.bgAccent.withValues(alpha: 0.45)),
                ),
                icon: const Icon(Icons.image_outlined, size: 16),
                label: Text(AppStrings.attachImage(lang)),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: AppStrings.enterText(lang),
                errorText: _error,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
              ),
              onSubmitted: (_) => _busy ? null : _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(AppStrings.cancel(lang)),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: theme.bgAccent),
          child: Text(
            AppStrings.saveChanges(lang),
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

