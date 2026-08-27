import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/utils/phrase_image_storage.dart';
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
    this.showAddAndAttach = true,
  });

  final Future<void> Function(String text, String? imagePath) onAdd;
  final String? addLabel;
  final PhraseComposerPanelController? composerController;
  final String? speakCategoryKey;
  final bool recordOnPlay;
  final bool showAddAndAttach;

  @override
  State<PhraseComposerPanel> createState() => _PhraseComposerPanelState();
}

class _PhraseComposerPanelState extends State<PhraseComposerPanel> {
  final _controller = HighlightingTextController();
  final _composerScroll = ScrollController();
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
      _keepComposerEndVisible();
    });
  }

  @override
  void dispose() {
    widget.composerController?._detach();
    _controller.dispose();
    _composerScroll.dispose();
    super.dispose();
  }

  /// Pins the composer to its last line while text is being added at the end,
  /// so the newest words stay visible once the box is full.
  void _keepComposerEndVisible() {
    final selection = _controller.selection;
    final atEnd =
        selection.isCollapsed &&
        selection.baseOffset >= _controller.text.length;
    if (!atEnd) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_composerScroll.hasClients) return;
      final maxOffset = _composerScroll.position.maxScrollExtent;
      if (_composerScroll.offset >= maxOffset) return;
      _composerScroll.jumpTo(maxOffset);
    });
  }

  /// Replaces composer text and leaves the caret at the end.
  void _setComposerText(String value) {
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void appendPhrase(String text, {bool speak = false}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final current = _controller.text.trim();
    _setComposerText(current.isEmpty ? trimmed : '$current $trimmed');
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
    final file = await ImagePicker().pickMedia(
      maxWidth: 900,
      imageQuality: 85,
    );
    if (file != null) setState(() => _imagePath = file.path);
  }

  void _clearComposer() {
    _controller.clear();
    _undoStack
      ..clear()
      ..add('');
    if (_composerScroll.hasClients) _composerScroll.jumpTo(0);
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
        Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.undo_rounded, size: 22),
                onPressed: _undoStack.length <= 1
                    ? null
                    : () {
                        _undoStack.removeLast();
                        _setComposerText(_undoStack.last);
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
        ),
        if (widget.showAddAndAttach && _imagePath != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  child: isPhraseVideoPath(_imagePath)
                      ? Container(
                          width: 52,
                          height: 52,
                          color: theme.bgMid,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.videocam_rounded,
                            color: theme.bgAccent,
                          ),
                        )
                      : Image.file(
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
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: ColoredBox(
                    color: Color.alphaBlend(
                      Colors.white.withValues(alpha: 0.32),
                      theme.bgLight.withValues(alpha: 0.18),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.34),
                          Colors.white.withValues(alpha: 0.05),
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.18),
                        ],
                        stops: const [0, 0.3, 0.66, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: 1.6,
                      sigmaY: 1.6,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
                          width: 2.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                scrollController: _composerScroll,
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
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (widget.showAddAndAttach) ...[
                const SizedBox(height: AppSpacing.sm),
                Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.end,
                  runAlignment: WrapAlignment.end,
                  children: [
                    FilledButton.icon(
                      onPressed: _pickImage,
                      style: FilledButton.styleFrom(
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        backgroundColor: Colors.white,
                        foregroundColor: theme.bgAccent,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
                      ),
                      icon: Icon(
                        Icons.perm_media_rounded,
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
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        backgroundColor: theme.bgAccent,
                        foregroundColor: Colors.white,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 16),
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
              style: FilledButton.styleFrom(
                elevation: 0,
                shadowColor: Colors.transparent,
                backgroundColor: theme.bgAccent,
                foregroundColor: Colors.white,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppSpacing.radiusSm,
                  ),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 16),
              label: Text(
                AppStrings.play(lang),
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: () => app.pauseSpeech(),
              style: FilledButton.styleFrom(
                elevation: 0,
                shadowColor: Colors.transparent,
                backgroundColor: theme.bgAccent,
                foregroundColor: Colors.white,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppSpacing.radiusSm,
                  ),
                ),
              ),
              icon: const Icon(Icons.pause_rounded, size: 16),
              label: Text(
                AppStrings.pause(lang),
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
