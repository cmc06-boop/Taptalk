import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';
import '../widgets/taptalk_logo.dart';
import '../widgets/taptalk_shell.dart';

const _brandGreen = Color(0xFF3ECF8E);
const _brandGreenSoft = Color(0xFFB3E6CC);
const _brandAccent = Color(0xFF5BB88A);
const _bodyText = Color(0xFF2F5E48);

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.language;

    return TapTalkShell(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 500;
          final compactHeight = constraints.maxHeight < 760;
          final screenH = constraints.maxHeight;
          // Larger green header so bubbles / abstract shapes have more room.
          final headerHeight = isWide
              ? screenH * 0.42
              : (compactHeight ? screenH * 0.46 : screenH * 0.52);
          final headerLogoSize = compactHeight ? 48.0 : 56.0;
          final contentHorizontal = isWide ? 36.0 : 24.0;
          final contentTop = compactHeight ? 36.0 : 48.0;
          final textBlockGap = compactHeight ? 10.0 : 14.0;
          final sheetOverlap = isWide ? 40.0 : 58.0;

          return Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: headerHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [_brandGreen, _brandGreenSoft],
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _floatController,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _AbstractBlobPainter(
                            phase: _floatController.value,
                          ),
                          size: Size(constraints.maxWidth, headerHeight),
                        );
                      },
                    ),
                    _FadeBubbleField(
                      animation: _floatController,
                      size: Size(constraints.maxWidth, headerHeight),
                    ),
                    Align(
                      alignment: const Alignment(0, -0.55),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          TapTalkLogo(size: headerLogoSize),
                          SizedBox(width: compactHeight ? 10 : 14),
                          Text(
                            'TapTalk',
                            style: GoogleFonts.poppins(
                              fontSize: compactHeight ? 34 : 38,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.4,
                              shadows: const [
                                Shadow(
                                  color: Color(0x22000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Transform.translate(
                  offset: Offset(0, -sheetOverlap),
                  child: ClipPath(
                    clipper: _FlowySheetClipper(),
                    child: Material(
                      color: Colors.white,
                      elevation: 0,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          contentHorizontal,
                          contentTop,
                          contentHorizontal,
                          compactHeight ? 14 : 18,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: compactHeight ? 4 : 8),
                            Text(
                              AppStrings.welcomeHeadline(lang),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: compactHeight ? 22 : 24,
                                fontWeight: FontWeight.w700,
                                color: _brandAccent,
                              ),
                            ),
                            SizedBox(height: textBlockGap),
                            Text(
                              AppStrings.welcomeTagline(lang),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: _bodyText.withValues(alpha: 0.88),
                                height: 1.45,
                              ),
                            ),
                            SizedBox(height: compactHeight ? 4 : 6),
                            Text(
                              AppStrings.hereWeGo(lang),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: compactHeight ? 16 : 17,
                                fontWeight: FontWeight.w600,
                                color: _bodyText,
                              ),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: () => app.setRoute(AppRoute.register),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.black,
                                padding: EdgeInsets.symmetric(
                                  vertical: compactHeight ? 14 : 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                AppStrings.signUp(lang),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            SizedBox(height: compactHeight ? 10 : 14),
                            Text.rich(
                              textAlign: TextAlign.center,
                              TextSpan(
                                text: lang == AppLanguage.filipino
                                    ? 'May account na? '
                                    : 'Already have an account? ',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: _bodyText,
                                ),
                                children: [
                                  WidgetSpan(
                                    child: GestureDetector(
                                      onTap: () =>
                                          app.setRoute(AppRoute.login),
                                      child: Text(
                                        AppStrings.loginTitle(lang),
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                          color: _brandAccent,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: compactHeight ? 4 : AppSpacing.xs),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Flowy wave cut on the white content sheet (abstract top edge).
class _FlowySheetClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, size.height * 0.1)
      ..quadraticBezierTo(
        size.width * 0.22,
        size.height * 0.02,
        size.width * 0.48,
        size.height * 0.08,
      )
      ..quadraticBezierTo(
        size.width * 0.76,
        size.height * 0.14,
        size.width,
        size.height * 0.05,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Soft organic white shapes in the header (no icons / figures).
class _AbstractBlobPainter extends CustomPainter {
  _AbstractBlobPainter({required this.phase});

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final drift = math.sin(phase * math.pi * 2) * 6;

    final paint = Paint()..color = Colors.white.withValues(alpha: 0.28);
    final blob = Path()
      ..moveTo(0, size.height * 0.72 + drift)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.35,
        size.width * 0.65,
        size.height * 0.58 + drift * 0.4,
      )
      ..quadraticBezierTo(
        size.width * 0.95,
        size.height * 0.78,
        size.width,
        size.height * 0.95,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(blob, paint);

    paint.color = Colors.white.withValues(alpha: 0.18);
    canvas.drawCircle(
      Offset(size.width * 0.1 + drift, size.height * 0.18),
      size.width * 0.24,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.86 - drift * 0.5, size.height * 0.32),
      size.width * 0.18,
      paint,
    );
    paint.color = Colors.white.withValues(alpha: 0.12);
    canvas.drawCircle(
      Offset(size.width * 0.5 + drift * 0.4, size.height * 0.55),
      size.width * 0.12,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AbstractBlobPainter old) => old.phase != phase;
}

/// Faded floating circles — only decorative motion in the header.
class _FadeBubbleField extends StatelessWidget {
  const _FadeBubbleField({
    required this.animation,
    required this.size,
  });

  final Animation<double> animation;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        return Stack(
          children: [
            _bubble(
              left: size.width * 0.04,
              top: size.height * (0.08 + math.sin(t * math.pi * 2) * 0.045),
              d: 68,
              alpha: 0.24,
            ),
            _bubble(
              right: size.width * 0.03,
              top: size.height * (0.18 + math.cos(t * math.pi * 2) * 0.04),
              d: 96,
              alpha: 0.17,
            ),
            _bubble(
              left: size.width * 0.52,
              top: size.height * (0.04 + math.sin(t * math.pi * 2 + 1.1) * 0.035),
              d: 48,
              alpha: 0.22,
            ),
            _bubble(
              right: size.width * 0.42,
              top: size.height * (0.38 + math.cos(t * math.pi * 2 + 0.8) * 0.03),
              d: 56,
              alpha: 0.15,
            ),
            _bubble(
              left: size.width * 0.16,
              bottom: size.height * (0.06 + math.cos(t * math.pi * 2 + 0.6) * 0.035),
              d: 82,
              alpha: 0.16,
            ),
            _bubble(
              right: size.width * 0.2,
              bottom: size.height * (0.1 + math.sin(t * math.pi * 2 + 2) * 0.03),
              d: 58,
              alpha: 0.2,
            ),
            _bubble(
              left: size.width * 0.72,
              bottom: size.height * (0.14 + math.sin(t * math.pi * 2 + 1.4) * 0.028),
              d: 40,
              alpha: 0.14,
            ),
          ],
        );
      },
    );
  }

  Widget _bubble({
    double? left,
    double? right,
    double? top,
    double? bottom,
    required double d,
    required double alpha,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: alpha),
        ),
      ),
    );
  }
}
