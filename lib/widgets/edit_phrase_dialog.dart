import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';
import 'composer_attachment_preview.dart';

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
    final file = await ImagePicker().pickMedia(
      maxWidth: 900,
      imageQuality: 85,
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

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_imagePath != null) ...[
              ComposerAttachmentPreview(
                path: _imagePath!,
                theme: theme,
                width: double.infinity,
                height: 80,
                onRemove: _busy ? () {} : _removeImage,
              ),
              const SizedBox(height: AppSpacing.md),
            ] else ...[
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickImage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.bgAccent,
                  side: BorderSide(color: theme.bgAccent.withValues(alpha: 0.45)),
                ),
                icon: const Icon(Icons.perm_media_rounded, size: 16),
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
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: Text(AppStrings.cancel(lang)),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(backgroundColor: theme.bgAccent),
                  child: Text(
                    AppStrings.saveChanges(lang),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

