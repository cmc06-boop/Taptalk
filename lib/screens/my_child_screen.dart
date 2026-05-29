import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../data/models/category_model.dart';
import '../data/repositories/app_repository.dart';
import '../data/models/phrase_usage_stat.dart';
import '../providers/app_state.dart';
import '../widgets/learner_scaffold.dart';
import '../widgets/panel_card.dart';

class MyChildScreen extends StatefulWidget {
  const MyChildScreen({super.key});

  @override
  State<MyChildScreen> createState() => _MyChildScreenState();
}

class _MyChildScreenState extends State<MyChildScreen> {
  ChildUsagePeriod _period = ChildUsagePeriod.today;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<PhraseUsageStat> _stats = [];
  List<CategoryModel> _childCategories = [];
  bool _loadingStats = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadStats());
  }

  Future<void> _reloadStats() async {
    final app = context.read<AppState>();
    if (app.selectedChild == null) {
      if (mounted) {
        setState(() {
          _stats = [];
          _childCategories = [];
        });
      }
      return;
    }
    setState(() => _loadingStats = true);
    final child = app.selectedChild!;
    final statsFuture = app.getSelectedChildPhraseStats(
      period: _period,
      month: _period == ChildUsagePeriod.month ? _selectedMonth : null,
    );
    final categoriesFuture = app.categoriesForUser(child.learnerId);
    final results = await Future.wait([statsFuture, categoriesFuture]);
    if (mounted) {
      setState(() {
        _stats = results[0] as List<PhraseUsageStat>;
        _childCategories = results[1] as List<CategoryModel>;
        _loadingStats = false;
      });
    }
  }

  List<DateTime> _monthOptions() {
    final now = DateTime.now();
    return List.generate(
      12,
      (i) => DateTime(now.year, now.month - i),
    );
  }

  Future<void> _showLinkChildDialog() async {
    final app = context.read<AppState>();
    final lang = app.language;
    final theme = app.theme;
    final controller = TextEditingController();
    var busy = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            AppStrings.linkChildCode(lang),
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: AppStrings.enterChildCodeHint(lang),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: Text(AppStrings.cancel(lang)),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setDialogState(() => busy = true);
                      final err = await app.linkChildByProfileCode(
                        controller.text.trim(),
                      );
                      if (!ctx.mounted) return;
                      if (err != null) {
                        setDialogState(() => busy = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(err)),
                          );
                        }
                        return;
                      }
                      Navigator.pop(ctx);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppStrings.childLinked(lang))),
                      );
                      await _reloadStats();
                    },
              style: FilledButton.styleFrom(
                backgroundColor: theme.bgAccent,
              ),
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(AppStrings.add(lang)),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  String _categoryLabel(AppState app, String categoryKey) {
    final normalizedKey = AppRepository.normalizeCategoryKey(categoryKey);
    for (final cat in [..._childCategories, ...app.categories]) {
      if (AppRepository.normalizeCategoryKey(cat.key) == normalizedKey ||
          AppRepository.normalizeCategoryKey(cat.name) == normalizedKey) {
        return app.localizedCategoryName(cat);
      }
    }
    return app.localizedCategoryKey(categoryKey);
  }

  Map<String, List<PhraseUsageStat>> _groupByCategory() {
    final grouped = <String, List<PhraseUsageStat>>{};
    for (final stat in _stats) {
      grouped.putIfAbsent(stat.categoryKey, () => []).add(stat);
    }
    for (final list in grouped.values) {
      list.sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        if (byCount != 0) return byCount;
        return a.text.compareTo(b.text);
      });
    }
    return grouped;
  }

  int _categoryUsageRank(List<PhraseUsageStat> items) {
    var max = 0;
    for (final stat in items) {
      if (stat.count > max) max = stat.count;
    }
    return max;
  }

  Widget _periodChip({
    required String label,
    required bool selected,
    required TapTalkThemeToken theme,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected
          ? theme.bgAccent
          : theme.bgMid.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : theme.textMain,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final child = app.selectedChild;
    final grouped = _groupByCategory();
    final categoryKeys = grouped.keys.toList()
      ..sort((a, b) {
        final byUsage = _categoryUsageRank(grouped[b]!)
            .compareTo(_categoryUsageRank(grouped[a]!));
        if (byUsage != 0) return byUsage;
        return _categoryLabel(app, a).compareTo(_categoryLabel(app, b));
      });

    return LearnerScaffold(
      title: AppStrings.appName(lang),
      currentRoute: AppRoute.myChild,
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 80),
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
                        AppStrings.myChild(lang),
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: theme.textMain,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        AppStrings.myChildSubtitle(lang),
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
              if (app.linkedChildren.length > 1) ...[
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: DropdownButtonFormField<int>(
                    key: ValueKey(app.selectedChildId),
                    initialValue: app.selectedChildId,
                    decoration: InputDecoration(
                      labelText: AppStrings.selectChild(lang),
                      filled: true,
                      fillColor: theme.bgMid.withValues(alpha: 0.55),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: app.linkedChildren
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.learnerId,
                            child: Text(c.fullName),
                          ),
                        )
                        .toList(),
                    onChanged: (id) {
                      if (id == null) return;
                      app.selectChild(id);
                      _reloadStats();
                    },
                  ),
                ),
              ] else if (child != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Row(
                    children: [
                      Icon(
                        Icons.child_care_outlined,
                        size: 20,
                        color: theme.bgAccent,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          child.fullName,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: theme.textMain,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              content: Text(
                                AppStrings.unlinkChildConfirm(
                                  lang,
                                  child.fullName,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(AppStrings.cancel(lang)),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(AppStrings.unlinkChild(lang)),
                                ),
                              ],
                            ),
                          );
                          if (confirm != true || !mounted) return;
                          await app.unlinkChild(child.learnerId);
                          await _reloadStats();
                        },
                        child: Text(
                          AppStrings.unlinkChild(lang),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.bgAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (child != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Text(
                    AppStrings.frequentlyUsed(lang),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.textMain,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _periodChip(
                        label: AppStrings.today(lang),
                        selected: _period == ChildUsagePeriod.today,
                        theme: theme,
                        onTap: () {
                          setState(() => _period = ChildUsagePeriod.today);
                          _reloadStats();
                        },
                      ),
                      _periodChip(
                        label: AppStrings.thisWeek(lang),
                        selected: _period == ChildUsagePeriod.thisWeek,
                        theme: theme,
                        onTap: () {
                          setState(() => _period = ChildUsagePeriod.thisWeek);
                          _reloadStats();
                        },
                      ),
                      _periodChip(
                        label: AppStrings.month(lang),
                        selected: _period == ChildUsagePeriod.month,
                        theme: theme,
                        onTap: () {
                          setState(() => _period = ChildUsagePeriod.month);
                          _reloadStats();
                        },
                      ),
                    ],
                  ),
                ),
                if (_period == ChildUsagePeriod.month) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: DropdownButtonFormField<DateTime>(
                      initialValue: _selectedMonth,
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: theme.bgMid.withValues(alpha: 0.55),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: _monthOptions()
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(
                                DateFormat.yMMMM(
                                  lang == AppLanguage.filipino ? 'fil_PH' : 'en_US',
                                ).format(m),
                                style: GoogleFonts.poppins(fontSize: 14),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (m) {
                        if (m == null) return;
                        setState(() => _selectedMonth = m);
                        _reloadStats();
                      },
                    ),
                  ),
                ],
              ],
              if (child == null)
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.35,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                      ),
                      child: Text(
                        AppStrings.noLinkedChild(lang),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: theme.textMain.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                )
              else if (_loadingStats)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_stats.isEmpty)
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.25,
                  child: Center(
                    child: Text(
                      AppStrings.noPhraseUsage(lang),
                      style: GoogleFonts.poppins(
                        color: theme.textMain.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                )
              else
                ...categoryKeys.map((categoryKey) {
                  final items = grouped[categoryKey]!;
                  final categoryLabel = _categoryLabel(app, categoryKey);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.sm,
                        ),
                        child: Text(
                          categoryLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: theme.textMain,
                          ),
                        ),
                      ),
                      PanelCard(
                        margin: const EdgeInsets.only(
                          left: AppSpacing.lg,
                          right: AppSpacing.lg,
                          bottom: AppSpacing.sm,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < items.length; i++) ...[
                              if (i > 0)
                                Divider(
                                  height: AppSpacing.lg,
                                  color: theme.textMain.withValues(alpha: 0.12),
                                ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      app.localizedPhrase(
                                        items[i].text,
                                        items[i].categoryKey,
                                      ),
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: theme.textMain,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    AppStrings.timesUsed(items[i].count),
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: theme.bgAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                }),
            ],
          ),
          Positioned(
            right: AppSpacing.lg,
            bottom: AppSpacing.md,
            child: FloatingActionButton(
              onPressed: _showLinkChildDialog,
              backgroundColor: theme.bgAccent,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
