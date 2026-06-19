import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/utils/speak_feedback.dart';
import '../providers/app_state.dart';
import 'highlighting_text_controller.dart';
import 'tts_speed_selector.dart';

/// External handle for appending phrases into [PhraseComposerPanel].
class PhraseComposerPanelController {
  _PhraseComposerPanelState? _state;

  void _attach(_PhraseComposerPanelState state) => _state = state;

  void _detach() => _state = null;

  void appendPhrase(String text, {bool speak = false}) {
    _state?.appendPhrase(text, speak: speak);
  }
}

/// Home-style phrase text box with image attach and add button.
class PhraseComposerPanel extends StatefulWidget {
  const PhraseComposerPanel({
    super.key,
    required this.onAdd,
    this.addLabel,
    this.composerController,
    this.speakCategoryKey,
    this.recordOnPlay = true,
  });

  final Future<void> Function(String text, String? imagePath) onAdd;
  final String? addLabel;
  final PhraseComposerPanelController? composerController;
  final String? speakCategoryKey;
  final bool recordOnPlay;

  @override
  State<PhraseComposerPanel> createState() => _PhraseComposerPanelState();
}

class _PhraseComposerPanelState extends State<PhraseComposerPanel> {
  final _controller = HighlightingTextController();
  final _undoStack = <String>[];
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    widget.composerController?._attach(this);
    _undoStack.add('');
    _controller.addListener(() {
      if (_undoStack.isEmpty || _undoStack.last != _controller.text) {
        _undoStack.add(_controller.text);
      }
    });
  }

  @override
  void dispose() {
    widget.composerController?._detach();
    _controller.dispose();
    super.dispose();
  }

  void appendPhrase(String text, {bool speak = false}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final current = _controller.text.trim();
    _controller.text = current.isEmpty ? trimmed : '$current $trimmed';
    if (speak) {
      speakWithFeedback(
        context,
        trimmed,
        record: widget.recordOnPlay,
        categoryKey: widget.speakCategoryKey,
      );
    }
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 900,
    );
    if (file != null) setState(() => _imagePath = file.path);
  }

  void _clearComposer() {
    _controller.clear();
    _undoStack
      ..clear()
      ..add('');
    setState(() => _imagePath = null);
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final image = _imagePath;
    _clearComposer();
    await widget.onAdd(text, image);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final addLabel = widget.addLabel ?? AppStrings.add(lang);
    final (start, end) = app.composerHighlightRange(_controller.text);
    _controller.updateHighlight(
      start: start,
      end: end,
      accent: theme.bgAccent,
    );

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
                  icon: const Icon(Icons.undo_rounded, size: 22),
                  onPressed: _undoStack.length <= 1
                      ? null
                      : () {
                          _undoStack.removeLast();
                          _controller.text = _undoStack.last;
                        },
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 22),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _controller.text));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: () async {
                    await context.read<AppState>().stopSpeech();
                    _clearComposer();
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                maxLines: 4,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
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
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.end,
                  runAlignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickImage,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.bgAccent,
                        backgroundColor: Colors.white.withValues(alpha: 0.92),
                        side: BorderSide(
                          color: theme.bgAccent.withValues(alpha: 0.45),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                      ),
                      icon: Icon(
                        Icons.image_outlined,
                        size: 16,
                        color: theme.bgAccent,
                      ),
                      label: Text(
                        AppStrings.attachImage(lang),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.bgAccent,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.bgAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(
                        addLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton.icon(
              onPressed: () => speakWithFeedback(
                context,
                _controller.text,
                record: widget.recordOnPlay,
                categoryKey: widget.speakCategoryKey,
              ),
              style: FilledButton.styleFrom(backgroundColor: theme.bgAccent),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(AppStrings.play(lang)),
            ),
            FilledButton.icon(
              onPressed: () => app.pauseSpeech(),
              style: FilledButton.styleFrom(backgroundColor: theme.bgAccent),
              icon: const Icon(Icons.pause_rounded),
              label: Text(AppStrings.pause(lang)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        TtsSpeedSelector(
          showScaleLabels: true,
          sectionLabel: AppStrings.speechSpeed(lang),
        ),
      ],
    );
  }
}
