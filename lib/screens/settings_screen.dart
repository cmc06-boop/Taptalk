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
      title: AppStrings.appName(lang),
      currentRoute: AppRoute.settings,
      showBottomNav: true,
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppStrings.settings(lang),
                    style: GoogleFonts.poppins(
                      fontSize: 22,
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
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          PanelCard(
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
                const SizedBox(height: AppSpacing.md),
                LanguageDropdownField(
                  value: lang,
                  label: AppStrings.language(lang),
                  onChanged: app.setLanguage,
                ),
              ],
            ),
          ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        const crossAxisCount = 2;
        const spacing = AppSpacing.sm;
        final itemWidth =
            (constraints.maxWidth - spacing) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: TapTalkThemes.all.map((t) {
            final selected = t.key == selectedKey;
            final label = app.localizedThemeName(t.key, t.name);
            return SizedBox(
              width: itemWidth,
              child: Material(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onSelect(t.key),
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(
                        color: selected ? accent : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: t.bgAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: t.textMain,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
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
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

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
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          boxShadow: [
            BoxShadow(
              color: theme.bgAccent.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
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
                              fontSize: 15,
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
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: child,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
