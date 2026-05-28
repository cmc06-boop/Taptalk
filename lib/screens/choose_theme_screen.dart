import 'package:flutter/material.dart';
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
  static const _mintBackground = Color(0xFFE8F8ED);
  static const _titleColor = Color(0xFF1F2937);
  static const _subColor = Color(0xFF6B7280);

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
      backgroundColor: _mintBackground,
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
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: _titleColor,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppStrings.chooseThemeSub(lang),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
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
                    final selected = _selected == t.key;
                    final tileColor = Color.alphaBlend(
                      Colors.white.withValues(alpha: 0.25),
                      t.bgAccent,
                    );

                    return Material(
                      color: tileColor,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => setState(() => _selected = t.key),
                        child: Ink(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF374151)
                                  : Colors.transparent,
                              width: 2.2,
                            ),
                          ),
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Center(
                            child: Text(
                              app.localizedThemeName(t.key, t.name),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: t.textMain,
                              ),
                            ),
                          ),
                        ),
                      ),
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
                    : () => app.completeThemeSelection(_selected!),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  disabledBackgroundColor: Colors.black.withValues(alpha: 0.35),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Text(
                  AppStrings.continueLabel(lang),
                  style: const TextStyle(
                    fontSize: 18,
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
              style: const TextStyle(
                fontSize: 11,
                color: _subColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
