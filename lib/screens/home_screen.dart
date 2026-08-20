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
import '../services/stt_service.dart';
import '../widgets/category_grid_card.dart';
import '../widgets/edit_phrase_dialog.dart';
import '../widgets/learner_scaffold.dart';
import '../widgets/panel_card.dart';
import '../widgets/phrase_card.dart';
import '../widgets/highlighting_text_controller.dart';
import '../widgets/tts_speed_selector.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = HighlightingTextController();
  final _undoStack = <String>[];
  final SttService _stt = SttService();
  bool _listening = false;
  String _micSessionPrefix = '';
  String? _attachedImagePath;

  @override
  void initState() {
    super.initState();
    _undoStack.add('');
    _textController.addListener(() {
      if (_undoStack.isEmpty || _undoStack.last != _textController.text) {
        _undoStack.add(_textController.text);
      }
    });
  }

  @override
  void dispose() {
    _stt.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _syncMicListening() {
    if (!mounted) return;
    final active = _stt.isListening;
    if (_listening != active) {
      setState(() => _listening = active);
    }
  }

  Future<void> _toggleMic() async {
    final app = context.read<AppState>();
    if (_listening || _stt.isListening) {
      await _stt.stop();
      _syncMicListening();
      return;
    }

    final ready = await _stt.initialize(
      onStatus: (_) => _syncMicListening(),
      onError: (error) {
        _syncMicListening();
        if (!mounted) return;
        if (error.permanent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.speechNotAvailable(app.language))),
          );
        }
      },
    );

    if (!ready) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.speechNotAvailable(app.language))),
      );
      return;
    }

    _micSessionPrefix = _textController.text;
    if (_micSessionPrefix.isNotEmpty && !_micSessionPrefix.endsWith(' ')) {
      _micSessionPrefix = '$_micSessionPrefix ';
    }

    setState(() => _listening = true);

    final locale = await _stt.resolveLocale(app.language);
    final started = await _stt.startListening(
      localeId: locale,
      onResult: (words, isFinal) {
        if (words.trim().isEmpty) return;
        if (!mounted) return;
        setState(() {
          _textController.text = '$_micSessionPrefix${words.trim()}';
        });
      },
    );
    _syncMicListening();
    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.speechNotAvailable(app.language))),
      );
    }
  }

  void _clearComposer() {
    _textController.clear();
    _undoStack
      ..clear()
      ..add('');
    setState(() => _attachedImagePath = null);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 900);
    if (file != null) {
      setState(() => _attachedImagePath = file.path);
    }
  }

  void _appendPhrase(String text, {bool speak = false}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final current = _textController.text.trim();
    _textController.text = current.isEmpty ? trimmed : '$current $trimmed';
    if (speak) {
      speakWithFeedback(context, trimmed, record: true);
    }
  }

  Future<void> _refresh() async {
    await context.read<AppState>().refreshLearnerCollections();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final denseGrid = AppSpacing.phraseGridIsDense(context);
    final parentCategory = app.selectedTopLevelCategory;
    final headerLabel = app.showingSubcategoryPicker
        ? (parentCategory != null
            ? app.localizedCategoryName(parentCategory)
            : AppStrings.customCategory(lang))
        : (app.selectedCategory != null
            ? app.localizedCategoryName(app.selectedCategory!)
            : AppStrings.customCategory(lang));
    final highlightController = _textController;
    if (highlightController is HighlightingTextController) {
      final (start, end) =
          app.composerHighlightRange(_textController.text);
      highlightController.updateHighlight(
        start: start,
        end: end,
        accent: theme.bgAccent,
      );
    }

    return PopScope(
      canPop: app.selectedSubcategoryKey == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        app.clearSubcategorySelection();
      },
      child: LearnerScaffold(
      title: headerLabel,
      currentRoute: AppRoute.home,
      onMicTap: _toggleMic,
      micActive: _listening,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: theme.bgAccent,
        child: ListView(
        key: ValueKey('home_${lang.name}_${app.languageRevision}'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          if (app.showingSubcategoryPicker)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                AppStrings.chooseSubcategoryHint(lang),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: theme.textMain.withValues(alpha: 0.75),
                ),
              ),
            ),
          if (app.showingSubcategoryPicker)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: GridView.builder(
                key: ValueKey(
                  'subcats_${lang.name}_${app.languageRevision}_${app.selectedCategoryKey}',
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: AppSpacing.phraseGridDelegate(context),
                itemCount: app.subcategoriesForSelected.length,
                itemBuilder: (context, i) {
                  final sub = app.subcategoriesForSelected[i];
                  return CategoryGridCard(
                    category: sub,
                    label: app.localizedCategoryName(sub),
                    onTap: () => app.selectSubcategory(sub.key),
                  );
                },
              ),
            )
          else ...[
          PanelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.enterText(lang),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: theme.textMain,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.undo_rounded, size: 22),
                          onPressed: _undoStack.length <= 1
                              ? null
                              : () {
                                  _undoStack.removeLast();
                                  _textController.text = _undoStack.last;
                                },
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.copy_rounded, size: 22),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: _textController.text),
                            );
                          },
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close_rounded, size: 22),
                          onPressed: () async {
                            await app.stopSpeech();
                            _clearComposer();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                if (_attachedImagePath != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          child: Image.file(
                            File(_attachedImagePath!),
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
                          onPressed: () => setState(() => _attachedImagePath = null),
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
                        controller: _textController,
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
                            onPressed: app.showingSubcategoryPicker
                                ? null
                                : () async {
                              final text = _textController.text.trim();
                              if (text.isEmpty) return;
                              final image = _attachedImagePath;
                              _clearComposer();
                              await app.addPhrase(text, imagePath: image);
                            },
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
                              AppStrings.add(lang),
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
                        _textController.text,
                        record: true,
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
            ),
          ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: GridView.builder(
                key: ValueKey(
                  'phrases_${lang.name}_${app.languageRevision}_${app.effectivePhraseCategoryKey}',
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: AppSpacing.phraseGridDelegate(context),
                itemCount: app.phrasesForCategory.length,
                itemBuilder: (context, i) {
                  final phrase = app.phrasesForCategory[i];
                  return PhraseCard(
                    key: ValueKey(
                      'phrase_${phrase.id}_${lang.name}_${app.languageRevision}',
                    ),
                    phrase: phrase,
                    dense: denseGrid,
                    isFavorite: app.isFavorite(phrase),
                    onTap: () => _appendPhrase(app.localizedPhraseText(phrase)),
                    onSpeak: () => _appendPhrase(
                      app.localizedPhraseText(phrase),
                      speak: true,
                    ),
                    onFavorite: () => app.toggleFavorite(phrase),
                    onEdit: () async {
                      if (phrase.isBuiltin) return;
                      final result = await EditPhraseDialog.show(
                        context,
                        initialText: app.localizedPhraseText(phrase),
                        initialImagePath: phrase.imagePath,
                        title: AppStrings.editPhrase(lang),
                      );
                      if (result == null || !mounted) return;
                      await app.updatePhrase(
                        phrase,
                        text: result.text,
                        imagePath: result.imagePath,
                        clearImage: result.clearImage,
                      );
                    },
                    onDelete: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          content: Text(AppStrings.deletePhrase(lang)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(AppStrings.cancel(lang)),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(AppStrings.delete(lang)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) await app.deletePhrase(phrase);
                    },
                  );
                },
              ),
            ),
          ],
        ],
        ),
      ),
      ),
    );
  }
}
