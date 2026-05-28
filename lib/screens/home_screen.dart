import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/utils/speak_feedback.dart';
import '../providers/app_state.dart';
import '../widgets/learner_scaffold.dart';
import '../widgets/panel_card.dart';
import '../widgets/phrase_card.dart';
import '../widgets/phrase_section_header.dart';
import '../widgets/tts_speed_selector.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _textController = TextEditingController();
  final _categoryScroll = ScrollController();
  final _undoStack = <String>[];
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _listening = false;
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
    _textController.dispose();
    _categoryScroll.dispose();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    final app = context.read<AppState>();
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    final available = await _speech.initialize();
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.speechNeedsInternet(app.language))),
        );
      }
      return;
    }
    setState(() => _listening = true);
    final locale = app.language == AppLanguage.filipino ? 'fil_PH' : 'en_US';
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(localeId: locale),
      onResult: (result) {
        if (result.finalResult) {
          final current = _textController.text.trim();
          final next = current.isEmpty
              ? result.recognizedWords
              : '$current ${result.recognizedWords}';
          _textController.text = next;
        }
      },
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 900);
    if (file != null) {
      setState(() => _attachedImagePath = file.path);
    }
  }

  void _appendPhrase(String text, {bool speak = false}) {
    final current = _textController.text.trim();
    _textController.text = current.isEmpty ? text : '$current $text';
    if (speak) {
      speakWithFeedback(context, _textController.text, record: true);
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final app = context.read<AppState>();
    final lang = app.language;
    final controller = TextEditingController();
    String? error;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(AppStrings.newCategory(lang)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: AppStrings.categoryNameHint(lang),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(error!, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppStrings.cancel(lang)),
            ),
            FilledButton(
              onPressed: () async {
                final err = await app.addCategory(controller.text);
                if (!ctx.mounted) return;
                if (err != null) {
                  setLocal(() => error = err);
                } else {
                  Navigator.pop(ctx);
                }
              },
              child: Text(AppStrings.add(lang)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final userName = app.user?.fullName ?? AppStrings.defaultLearnerName(lang);
    final columns = AppSpacing.phraseGridColumns(context);

    return LearnerScaffold(
      title: AppStrings.appName(lang),
      currentRoute: AppRoute.home,
      onMicTap: _toggleMic,
      micActive: _listening,
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          PanelCard(
            margin: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.welcomeUser(userName, lang),
                  style: GoogleFonts.tiltWarp(
                    fontSize: 22,
                    color: theme.textMain,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppStrings.welcomeSub(lang),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: theme.textMain.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppStrings.categories(lang),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: theme.textMain,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showAddCategoryDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                    AppStrings.addCategory(lang),
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              controller: _categoryScroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: app.categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) {
                final cat = app.categories[i];
                final active = cat.key == app.selectedCategoryKey;
                return FilterChip(
                  selected: active,
                  showCheckmark: false,
                  label: Text(app.localizedCategoryName(cat)),
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color: active ? Colors.white : theme.textMain,
                  ),
                  selectedColor: theme.bgAccent,
                  backgroundColor: Colors.white.withValues(alpha: 0.65),
                  side: BorderSide(color: theme.bgMid, width: 1.5),
                  onSelected: (_) => app.selectCategory(cat.key),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          PanelCard(
            child: Column(
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
                                  _textController.text = _undoStack.last;
                                },
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 22),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: _textController.text),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 22),
                          onPressed: () {
                            app.tts.stop();
                            _textController.clear();
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
                    children: [
                      TextField(
                        controller: _textController,
                        maxLines: 4,
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
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.bgAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          FilledButton.icon(
                            onPressed: () async {
                              await app.addPhrase(
                                _textController.text,
                                imagePath: _attachedImagePath,
                              );
                              _textController.clear();
                              setState(() => _attachedImagePath = null);
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
                      onPressed: () => app.tts.pause(),
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
          PhraseSectionHeader(
            category: app.selectedCategory,
            categoryLabel: app.selectedCategory != null
                ? app.localizedCategoryName(app.selectedCategory!)
                : AppStrings.customCategory(lang),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                childAspectRatio: 0.86,
              ),
              itemCount: app.phrasesForCategory.length,
              itemBuilder: (context, i) {
                final phrase = app.phrasesForCategory[i];
                return Align(
                  alignment: Alignment.topCenter,
                  child: PhraseCard(
                    phrase: phrase,
                    isFavorite: app.isFavorite(phrase),
                    onTap: () => _appendPhrase(app.localizedPhraseText(phrase)),
                    onSpeak: () =>
                        _appendPhrase(app.localizedPhraseText(phrase), speak: true),
                    onFavorite: () => app.toggleFavorite(phrase),
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
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
