import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';
import 'inline_dropdown_field.dart';

/// Shared language picker — same inline dropdown style as the teacher dashboard.
class LanguageDropdownField extends StatelessWidget {
  const LanguageDropdownField({
    super.key,
    required this.value,
    required this.onChanged,
    this.uiLanguage,
    this.label,
    this.prominent = false,
  });

  final AppLanguage value;
  final ValueChanged<AppLanguage> onChanged;
  final AppLanguage? uiLanguage;
  final String? label;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppState>().theme;
    final lang = uiLanguage ?? context.watch<AppState>().language;

    final valueFontSize = prominent ? 16.0 : 14.0;
    final optionFontSize = prominent ? 16.0 : 14.0;
    final iconSize = prominent ? 24.0 : 22.0;
    final fieldBorderRadius = prominent ? 12.0 : 10.0;
    final triggerPadding = prominent
        ? const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          )
        : const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 4,
            vertical: AppSpacing.xs + 4,
          );

    final dropdown = InlineDropdownField<AppLanguage>(
      overlayMenu: true,
      value: AppStrings.languageDisplay(value, lang),
      options: AppLanguage.values,
      optionLabel: (l) => AppStrings.languageDisplay(l, lang),
      selected: value,
      theme: theme,
      maxMenuHeight: prominent ? 140 : 120,
      valueFontSize: valueFontSize,
      optionFontSize: optionFontSize,
      triggerPadding: triggerPadding,
      iconSize: iconSize,
      fieldBorderRadius: fieldBorderRadius,
      triggerBackgroundColor: prominent
          ? null
          : Color.lerp(theme.bgLight, Colors.white, 0.35),
      idleBorderColor: prominent
          ? null
          : theme.textMain.withValues(alpha: 0.12),
      triggerBoxShadow: prominent
          ? null
          : [
              BoxShadow(
                color: theme.textMain.withValues(alpha: 0.07),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
      onSelected: onChanged,
    );

    if (label == null || label!.isEmpty) {
      return dropdown;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label!,
          style: GoogleFonts.poppins(
            fontSize: prominent ? 14 : 12,
            fontWeight: FontWeight.w600,
            color: theme.textMain.withValues(alpha: 0.85),
          ),
        ),
        SizedBox(height: prominent ? AppSpacing.sm : AppSpacing.xs),
        dropdown,
      ],
    );
  }
}
