import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../providers/app_state.dart';
import '../widgets/taptalk_shell.dart';

class ChooseThemeScreen extends StatefulWidget {
  const ChooseThemeScreen({super.key});

  @override
  State<ChooseThemeScreen> createState() => _ChooseThemeScreenState();
}

class _ChooseThemeScreenState extends State<ChooseThemeScreen> {
  static const _titleColor = Color(0xFF1E3A2C);
  static const _subColor = Color(0xFF4F6C5D);

  String? _selected;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    final userTheme = app.user?.themeKey;
    _selected = app.user?.needsTheme == true ? null : userTheme;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.language;

    return TapTalkShell(
      backgroundColor: Color.alphaBlend(
        const Color(0x22FFFFFF),
        app.theme.bgLight,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Column(
              children: [
                Text(
                  AppStrings.chooseThemeTitle(lang),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: _titleColor,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppStrings.chooseThemeSub(lang),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: _subColor,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth - (AppSpacing.lg * 2);
                final count = TapTalkThemes.all.length;
                final crossAxisCount = width >= 700 ? 4 : (width >= 500 ? 3 : 2);
                final rows = (count / crossAxisCount).ceil();
                final totalVSpacing = (rows - 1) * AppSpacing.md;
                final usableHeight =
                    (constraints.maxHeight - totalVSpacing).clamp(1.0, double.infinity);
                final itemHeight = usableHeight / rows;
                final itemWidth =
                    (width - ((crossAxisCount - 1) * AppSpacing.md)) / crossAxisCount;
                final childAspectRatio = itemWidth / itemHeight;

                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: count,
                  itemBuilder: (context, i) {
                    final t = TapTalkThemes.all[i];
                    return _ThemeTile(
                      token: t,
                      label: app.localizedThemeName(t.key, t.name),
                      selected: _selected == t.key,
                      onTap: () {
                        setState(() => _selected = t.key);
                        app.previewTheme(t.key);
                      },
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selected == null
                    ? null
                    : () {
                        app.completeThemeSelection(_selected!);
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  disabledBackgroundColor: Colors.black.withValues(alpha: 0.35),
                  minimumSize: const Size(double.infinity, 50),
                  padding: const EdgeInsets.symmetric(vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  AppStrings.continueLabel(lang).replaceAll('→', '').trimRight(),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Text(
              AppStrings.chooseThemeFooter(lang),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: _subColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatefulWidget {
  const _ThemeTile({
    required this.token,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final TapTalkThemeToken token;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ThemeTile> createState() => _ThemeTileState();
}

class _ThemeTileState extends State<_ThemeTile> {
  bool _hovering = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.token;
    final tileColor = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.45),
      t.bgAccent,
    );
    final scale = _pressed ? 0.97 : (_hovering ? 1.02 : 1.0);

    return AnimatedScale(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      scale: scale,
      child: Material(
        color: tileColor,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (value) => setState(() => _hovering = value),
          onHighlightChanged: (value) => setState(() => _pressed = value),
          splashColor: t.bgAccent.withValues(alpha: 0.15),
          highlightColor: t.bgAccent.withValues(alpha: 0.08),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.selected ? t.bgAccent : t.bgAccent.withValues(alpha: 0.28),
                width: widget.selected ? 2.4 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.selected
                      ? t.bgAccent.withValues(alpha: 0.25)
                      : t.bgAccent.withValues(alpha: _hovering ? 0.16 : 0.08),
                  blurRadius: widget.selected ? 14 : (_hovering ? 10 : 6),
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Center(
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 13,
                  color: widget.selected ? t.textMain : t.textMain.withValues(alpha: 0.92),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
