import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/utils/speak_feedback.dart';
import '../core/theme/theme_tokens.dart';
import '../core/l10n/content_localization.dart';
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
  List<HistoryModel> _items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFromApp());
  }

  void _syncFromApp() {
    final history = context.read<AppState>().history;
    if (!_sameItems(history)) {
      setState(() => _items = List.from(history));
    }
  }

  bool _sameItems(List<HistoryModel> source) {
    if (_items.length != source.length) return false;
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].id != source[i].id) return false;
    }
    return true;
  }

  void _removeItem(HistoryModel item) {
    setState(() => _items.removeWhere((e) => e.id == item.id));
    context.read<AppState>().deleteHistoryItem(item);
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
    setState(() => _items = []);
    await context.read<AppState>().clearAllHistory();
  }

  String _categoryLabel(AppState app, HistoryModel item, AppLanguage lang) {
    var categoryLabel = item.categoryKey;
    for (final cat in app.categories) {
      if (cat.key == item.categoryKey) {
        categoryLabel = app.localizedCategoryName(cat);
        break;
      }
    }
    if (categoryLabel == item.categoryKey) {
      categoryLabel = ContentLocalization.category(
        item.categoryKey,
        item.categoryKey,
        lang,
      );
    }
    return categoryLabel;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final fmt = DateFormat('d MMM - h:mm a');

    if (!_sameItems(app.history)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncFromApp();
      });
    }

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
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: theme.textMain,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppStrings.historySubtitle(lang),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
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
            ..._items.map(
              (item) => _HistoryCard(
                key: ValueKey(item.id),
                item: item,
                categoryLabel: _categoryLabel(app, item, lang),
                formattedTime: fmt.format(item.createdAt),
                theme: theme,
                lang: lang,
                onRemove: () => _removeItem(item),
                onSpeak: () =>
                    speakWithFeedback(context, item.text, record: false),
              ),
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
    final phraseText = ContentLocalization.phrase(
      widget.item.text,
      widget.item.categoryKey,
      lang: widget.lang,
    );
    final theme = widget.theme;

    return ClipRect(
      child: SizeTransition(
        sizeFactor: _collapse,
        axisAlignment: 0,
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
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                  color: theme.textMain.withValues(alpha: 0.55),
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
