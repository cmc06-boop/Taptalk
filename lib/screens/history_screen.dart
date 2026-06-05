import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/utils/speak_feedback.dart';
import '../core/theme/theme_tokens.dart';
import '../data/models/history_model.dart';
import '../providers/app_state.dart';
import '../widgets/learner_scaffold.dart';
import '../widgets/panel_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  List<HistoryModel> _items = [];

  @override
  void initState() {
    super.initState();
    _items = List.from(context.read<AppState>().history);
  }

  void _mergeNewHistory(List<HistoryModel> source) {
    if (source.isEmpty) {
      if (_items.isNotEmpty) {
        setState(() {
          _items = [];
          _listKey = GlobalKey<AnimatedListState>();
        });
      }
      return;
    }
    final hasNewEntries = source.length > _items.length ||
        (_items.isNotEmpty && source.first.id != _items.first.id);
    if (hasNewEntries) {
      setState(() {
        _items = List.from(source);
        _listKey = GlobalKey<AnimatedListState>();
      });
    }
  }

  void _removeItem(HistoryModel item) {
    final index = _items.indexWhere((e) => e.id == item.id);
    if (index < 0) return;

    _items.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
      _buildRemoveTransition,
      duration: const Duration(milliseconds: 120),
    );
    context.read<AppState>().deleteHistoryItem(item);
    setState(() {});
  }

  Widget _buildRemoveTransition(BuildContext context, Animation<double> animation) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubic,
    );
    return SizeTransition(
      sizeFactor: curved,
      alignment: Alignment.topCenter,
      child: const SizedBox.shrink(),
    );
  }

  Future<void> _clearAll(AppLanguage lang) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(AppStrings.clearAllHistoryConfirm(lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel(lang)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.clearAll(lang)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() {
      _items = [];
      _listKey = GlobalKey<AnimatedListState>();
    });
    await context.read<AppState>().clearAllHistory();
  }

  String _categoryLabel(AppState app, HistoryModel item, AppLanguage lang) {
    if (item.isLessonEntry) {
      return item.lessonContext!.className;
    }
    var categoryLabel = item.categoryKey;
    for (final cat in app.categories) {
      if (cat.key == item.categoryKey) {
        categoryLabel = app.localizedCategoryName(cat);
        break;
      }
    }
    if (categoryLabel == item.categoryKey) {
      categoryLabel = app.localizedCategoryKey(item.categoryKey);
    }
    return categoryLabel;
  }

  Widget _buildCard(HistoryModel item) {
    final app = context.read<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final fmt = DateFormat('d MMM - h:mm a');

    return _HistoryCard(
      key: ValueKey(item.id),
      item: item,
      categoryLabel: _categoryLabel(app, item, lang),
      formattedTime: fmt.format(item.createdAt),
      theme: theme,
      lang: lang,
      onRemove: () => _removeItem(item),
      onSpeak: () => speakWithFeedback(
            context,
            item.text,
            record: false,
            categoryKey: item.categoryKey,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;

    _mergeNewHistory(app.history);

    return LearnerScaffold(
      title: AppStrings.appName(lang),
      currentRoute: AppRoute.history,
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.bgMid.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.history(lang),
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: theme.textMain,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppStrings.historySubtitle(lang),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: theme.textMain.withValues(alpha: 0.72),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_items.isEmpty)
            SizedBox(
              width: double.infinity,
              height: MediaQuery.sizeOf(context).height * 0.38,
              child: Center(
                child: Text(
                  AppStrings.emptyHistory(lang),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: theme.textMain.withValues(alpha: 0.7),
                  ),
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _clearAll(lang),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.bgAccent,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    AppStrings.clearAll(lang),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.bgAccent,
                    ),
                  ),
                ),
              ),
            ),
            AnimatedList(
              key: _listKey,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              initialItemCount: _items.length,
              itemBuilder: (context, index, animation) {
                if (index >= _items.length) return const SizedBox.shrink();
                return FadeTransition(
                  opacity: animation,
                  child: _buildCard(_items[index]),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryCard extends StatefulWidget {
  const _HistoryCard({
    super.key,
    required this.item,
    required this.categoryLabel,
    required this.formattedTime,
    required this.theme,
    required this.lang,
    required this.onRemove,
    required this.onSpeak,
  });

  final HistoryModel item;
  final String categoryLabel;
  final String formattedTime;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final VoidCallback onRemove;
  final VoidCallback onSpeak;

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dismissController;
  late final Animation<double> _collapse;
  late final Animation<Offset> _slideOut;
  late final Animation<double> _fadeOut;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _dismissController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    final curve = CurvedAnimation(
      parent: _dismissController,
      curve: Curves.easeInCubic,
    );
    _slideOut = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.15, 0),
    ).animate(curve);
    _fadeOut = Tween<double>(begin: 1, end: 0).animate(curve);
    _collapse = Tween<double>(begin: 1, end: 0).animate(curve);
  }

  @override
  void dispose() {
    _dismissController.dispose();
    super.dispose();
  }

  Future<void> _animateDelete() async {
    if (_deleting) return;
    setState(() => _deleting = true);
    await _dismissController.forward();
    if (mounted) widget.onRemove();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final phraseText = app.localizedPhrase(
      widget.item.text,
      widget.item.categoryKey,
    );
    final lessonClassName = widget.item.lessonContext == null
        ? null
        : app.localizedContent(widget.item.lessonContext!.className);
    final lessonTitle = widget.item.lessonContext == null
        ? null
        : app.localizedContent(widget.item.lessonContext!.lessonTitle);
    final theme = widget.theme;

    return ClipRect(
      child: SizeTransition(
        sizeFactor: _collapse,
        alignment: Alignment.topCenter,
        child: FadeTransition(
          opacity: _fadeOut,
          child: SlideTransition(
            position: _slideOut,
            child: PanelCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _deleting ? null : widget.onSpeak,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusLg),
                        child: Padding(
                          padding:
                              const EdgeInsets.only(right: AppSpacing.xs),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.item.isLessonEntry) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.bgAccent,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    lessonClassName!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (widget.item.text.trim() !=
                                    widget.item.lessonContext!.lessonTitle
                                        .trim()) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    lessonTitle!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: theme.textMain
                                          .withValues(alpha: 0.75),
                                    ),
                                  ),
                                ],
                              ] else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.bgAccent,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    widget.categoryLabel,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                widget.formattedTime,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color:
                                      theme.textMain.withValues(alpha: 0.55),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                phraseText,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: theme.textMain,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: theme.textMain.withValues(alpha: 0.45),
                    tooltip: AppStrings.delete(widget.lang),
                    onPressed: _deleting ? null : _animateDelete,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
