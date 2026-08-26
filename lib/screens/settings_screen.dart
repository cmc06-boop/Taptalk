import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../providers/app_state.dart';
import '../widgets/learner_scaffold.dart';
import '../widgets/language_dropdown_field.dart';
import '../widgets/panel_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int? _openAccordionIndex;

  void _onAccordionTap(int index) {
    setState(() {
      // Close the previous section when a different one is opened.
      _openAccordionIndex = _openAccordionIndex == index ? null : index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;

    return LearnerScaffold(
      title: AppStrings.settings(lang),
      titleWidget: SizedBox(
        height: 85,
        child: Center(
          child: Text(
            AppStrings.settings(lang),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: theme.textMain,
            ),
          ),
        ),
      ),
      currentRoute: AppRoute.settings,
      headerContentHeight: 85,
      headerBottomSpacing: 0,
      bodyTopOffset: -4,
      showBottomNav: true,
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Container(
              width: double.infinity,
              clipBehavior: Clip.hardEdge,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: theme.bgMid.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppStrings.preferences(lang),
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: theme.textMain,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppStrings.settingsSubtitle(lang),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: theme.textMain.withValues(alpha: 0.72),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  LanguageDropdownField(
                    value: lang,
                    label: AppStrings.language(lang),
                    onChanged: app.setLanguage,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SettingsAccordion(
            key: const ValueKey('settings_accordion_help'),
            title: AppStrings.helpSupport(lang),
            expanded: _openAccordionIndex == 0,
            onToggle: () => _onAccordionTap(0),
            child: Text(
              AppStrings.contactSupport(lang),
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: theme.textMain.withValues(alpha: 0.9),
                height: 1.45,
              ),
            ),
          ),
          _SettingsAccordion(
            key: const ValueKey('settings_accordion_about'),
            title: AppStrings.aboutUs(lang),
            expanded: _openAccordionIndex == 1,
            onToggle: () => _onAccordionTap(1),
            child: Text(
              AppStrings.aboutBody(lang),
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: theme.textMain.withValues(alpha: 0.9),
                height: 1.45,
              ),
            ),
          ),
          _SettingsAccordion(
            key: const ValueKey('settings_accordion_theme'),
            title: AppStrings.theme(lang),
            expanded: _openAccordionIndex == 2,
            onToggle: () => _onAccordionTap(2),
            expandedPadding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: _ThemePickerGrid(
              selectedKey: theme.key,
              onSelect: app.setTheme,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: TextButton.icon(
              onPressed: app.logout,
              style: TextButton.styleFrom(
                foregroundColor: theme.textMain,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
              ),
              icon: Icon(
                Icons.logout_rounded,
                size: 20,
                color: theme.textMain,
              ),
              label: Text(
                AppStrings.logout(lang),
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: theme.textMain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemePickerGrid extends StatelessWidget {
  const _ThemePickerGrid({
    required this.selectedKey,
    required this.onSelect,
  });

  final String selectedKey;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final accent = app.theme.bgAccent;

    final themes = TapTalkThemes.all;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: themes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        mainAxisExtent: 40,
      ),
      itemBuilder: (context, index) {
        final t = themes[index];
        final selected = t.key == selectedKey;
        final label = app.localizedThemeName(t.key, t.name);
        return Material(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onSelect(t.key),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? accent : Colors.transparent,
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: t.bgAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: t.textMain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SettingsAccordion extends StatelessWidget {
  const _SettingsAccordion({
    super.key,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.expandedPadding,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;
  final EdgeInsetsGeometry? expandedPadding;

  Color _expandedBodyColor(TapTalkThemeToken theme) {
    return Color.alphaBlend(
      Colors.white.withValues(alpha: 0.52),
      theme.bgAccent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppState>().theme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: theme.bgAccent.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: theme.bgAccent,
                child: InkWell(
                  onTap: onToggle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        AnimatedRotation(
                          turns: expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (expanded)
                Container(
                  width: double.infinity,
                  color: _expandedBodyColor(theme),
                  padding: expandedPadding ??
                      const EdgeInsets.all(AppSpacing.md),
                  child: child,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
