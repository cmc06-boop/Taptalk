import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';
import '../widgets/taptalk_logo.dart';
import '../widgets/taptalk_shell.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _showMain = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showMain = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.language;

    return TapTalkShell(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 800),
        child: !_showMain
            ? _Splash(key: const ValueKey('splash'))
            : _WelcomeContent(
                key: const ValueKey('main'),
                lang: lang,
                onSignUp: () => app.setRoute(AppRoute.register),
              ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, 0.3),
          radius: 1.2,
          colors: [Color(0xFF3ECF8E), Color(0xFFB3E6CC), Color(0xFFD6F3E3)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TapTalkLogo(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'TapTalk',
              style: GoogleFonts.tiltWarp(
                fontSize: 28,
                color: Colors.white,
                shadows: const [
                  Shadow(blurRadius: 28, color: Colors.black26, offset: Offset(0, 10)),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _WelcomeContent extends StatelessWidget {
  const _WelcomeContent({
    super.key,
    required this.lang,
    required this.onSignUp,
  });

  final AppLanguage lang;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 220,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3ECF8E), Color(0xFFB3E6CC)],
            ),
          ),
          alignment: Alignment.bottomCenter,
          child: Text(
            'TapTalk',
            style: GoogleFonts.tiltWarp(fontSize: 32, color: Colors.white),
          ),
        ),
        Expanded(
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(120)),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  const Spacer(),
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF7CB518),
                          const Color(0xFF9BE15D).withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _dot(active: false),
                      _dot(active: false),
                      _dot(active: true),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    AppStrings.hereWeGo(lang),
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onSignUp,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        AppStrings.signUp(lang),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        context.read<AppState>().setRoute(AppRoute.login),
                    child: Text(
                      AppStrings.loginTitle(lang),
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF5BB88A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dot({required bool active}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: active ? 20 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF7ED957) : const Color(0xFFCCCCCC),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
