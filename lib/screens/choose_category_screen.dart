import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../data/models/category_model.dart';
import '../providers/app_state.dart';
import '../widgets/add_category_dialog.dart';
import '../widgets/taptalk_shell.dart';

class ChooseCategoryScreen extends StatefulWidget {
  const ChooseCategoryScreen({super.key});

  @override
  State<ChooseCategoryScreen> createState() => _ChooseCategoryScreenState();
}

class _ChooseCategoryScreenState extends State<ChooseCategoryScreen> {
  static const _continueBlack = Colors.black;

  String? _selected;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    _selected = app.categories.isNotEmpty ? app.categories.first.key : null;
  }

  Future<void> _showAddCategoryDialog() async {
    final selectedKey = await AddCategoryDialog.show(context);
    if (!mounted || selectedKey == null) return;
    setState(() => _selected = selectedKey);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.language;
    final theme = app.theme;
    final name = app.user?.fullName ?? AppStrings.defaultLearnerName(lang);
    final categoryColumns = AppSpacing.categoryGridColumns(context);

    return TapTalkShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppStrings.chooseCategoryTitle(lang),
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: theme.textMain,
                  ),
                ),
                TextButton(
                  onPressed: _showAddCategoryDialog,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: BorderSide(
                        color: theme.bgAccent.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  child: Text(
                    AppStrings.addCategoryShort(lang),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      color: theme.bgAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: const Color(0xFFE9EEF2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.hiUser(name, lang),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.textMain,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppStrings.chooseCategorySub(lang),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: theme.textMain.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: categoryColumns,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: categoryColumns >= 5 ? 1.05 : 0.96,
              ),
              itemCount: app.categories.length,
              itemBuilder: (context, i) {
                final cat = app.categories[i];
                return _CategoryCard(
                  category: cat,
                  label: app.localizedCategoryName(cat),
                  theme: theme,
                  selected: _selected == cat.key,
                  onTap: () => setState(() => _selected = cat.key),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selected == null
                    ? null
                    : () => app.completeCategorySelection(_selected!),
                style: FilledButton.styleFrom(
                  backgroundColor: _continueBlack,
                  disabledBackgroundColor: _continueBlack.withValues(alpha: 0.4),
                  minimumSize: const Size(double.infinity, 50),
                  padding: const EdgeInsets.symmetric(vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  AppStrings.continueLabel(lang).replaceAll('→', '').trimRight(),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatefulWidget {
  const _CategoryCard({
    required this.category,
    required this.label,
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final CategoryModel category;
  final String label;
  final TapTalkThemeToken theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _hovering = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final scale = _pressed ? 0.97 : (_hovering ? 1.02 : 1.0);

    return AnimatedScale(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      scale: scale,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: theme.bgAccent.withValues(alpha: 0.14),
          highlightColor: theme.bgAccent.withValues(alpha: 0.08),
          onTap: widget.onTap,
          onHover: (value) => setState(() => _hovering = value),
          onHighlightChanged: (value) => setState(() => _pressed = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: widget.selected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.bgMid.withValues(alpha: 0.45),
                        theme.bgLight.withValues(alpha: 0.95),
                      ],
                    )
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Color(0xFFF9FBFC)],
                    ),
              border: Border.all(
                color: widget.selected
                    ? theme.bgAccent.withValues(alpha: 0.9)
                    : const Color(0xFFE9EEF2),
                width: widget.selected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.selected
                      ? theme.bgAccent.withValues(alpha: 0.22)
                      : (_hovering
                          ? theme.bgAccent.withValues(alpha: 0.12)
                          : const Color(0x11000000)),
                  blurRadius: widget.selected ? 14 : (_hovering ? 10 : 8),
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                style: GoogleFonts.poppins(
                  fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 13,
                  color: widget.selected ? theme.textMain : Colors.black87,
                ),
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
