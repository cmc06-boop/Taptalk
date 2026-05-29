import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../providers/app_state.dart';

/// Home-style phrase text box with image attach and add button.
class PhraseComposerPanel extends StatefulWidget {
  const PhraseComposerPanel({
    super.key,
    required this.onAdd,
    this.addLabel,
  });

  final Future<void> Function(String text, String? imagePath) onAdd;
  final String? addLabel;

  @override
  State<PhraseComposerPanel> createState() => _PhraseComposerPanelState();
}

class _PhraseComposerPanelState extends State<PhraseComposerPanel> {
  final _controller = TextEditingController();
  String? _imagePath;

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
    if (file != null) setState(() => _imagePath = file.path);
  }

  Future<void> _submit() async {
    final text = _controller.text;
    final image = _imagePath;
    await widget.onAdd(text, image);
    if (!mounted) return;
    _controller.clear();
    setState(() => _imagePath = null);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppStrings.enterText(lang),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: theme.textMain,
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 22),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _controller.text));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: () {
                    app.stopSpeech();
                    _controller.clear();
                    setState(() => _imagePath = null);
                  },
                ),
              ],
            ),
          ],
        ),
        if (_imagePath != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  child: Image.file(
                    File(_imagePath!),
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    AppStrings.imageAttached(lang),
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _imagePath = null),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFFE8EFE2),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                maxLines: 4,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: theme.textMain,
                  height: 1.45,
                ),
                decoration: InputDecoration(
                  hintText: AppStrings.enterText(lang),
                  filled: true,
                  fillColor: const Color(0xFFF4F4F4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.bgAccent,
                      backgroundColor: Colors.white.withValues(alpha: 0.92),
                      side: BorderSide(
                        color: theme.bgAccent.withValues(alpha: 0.45),
                      ),
                    ),
                    icon: Icon(Icons.image_outlined, size: 16, color: theme.bgAccent),
                    label: Text(
                      AppStrings.attachImage(lang),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.bgAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.bgAccent,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      widget.addLabel ?? AppStrings.add(lang),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
