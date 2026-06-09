import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';
import '../widgets/language_dropdown_field.dart';
import '../widgets/taptalk_shell.dart';

class ChooseLanguageScreen extends StatefulWidget {
  const ChooseLanguageScreen({super.key});

  @override
  State<ChooseLanguageScreen> createState() => _ChooseLanguageScreenState();
}

class _ChooseLanguageScreenState extends State<ChooseLanguageScreen> {
  static const _titleColor = Color(0xFF1E3A2C);
  static const _subColor = Color(0xFF4F6C5D);

  late AppLanguage _selected;

  @override
  void initState() {
    super.initState();
    _selected = AppLanguage.english;
  }

  void _onLanguageChanged(AppLanguage lang) {
    setState(() => _selected = lang);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final guideLang = _selected;

    return TapTalkShell(
      backgroundColor: Color.alphaBlend(
        const Color(0x22FFFFFF),
        app.theme.bgLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg + MediaQuery.paddingOf(context).top,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppStrings.chooseLanguageTitle(guideLang),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: _titleColor,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppStrings.chooseLanguageSub(guideLang),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: _subColor,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                LanguageDropdownField(
                  value: _selected,
                  uiLanguage: guideLang,
                  label: AppStrings.language(guideLang),
                  prominent: true,
                  onChanged: _onLanguageChanged,
                ),
              ],
            ),
          ),
          const Spacer(),
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
                onPressed: () => app.completeLanguageSelection(_selected),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  padding: const EdgeInsets.symmetric(vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  AppStrings.continueLabel(guideLang)
                      .replaceAll('→', '')
                      .trimRight(),
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
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
            ),
            child: Text(
              AppStrings.chooseLanguageFooter(guideLang),
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
