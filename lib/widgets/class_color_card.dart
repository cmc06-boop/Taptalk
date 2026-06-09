import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../providers/app_state.dart';

/// Stable, distinct color identity per class (by [classId]).
class ClassColorScheme {
  const ClassColorScheme({
    required this.primary,
    required this.secondary,
    required this.label,
  });

  final Color primary;
  final Color secondary;
  final String label;

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primary, secondary],
      );

  LinearGradient get softGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.alphaBlend(primary.withValues(alpha: 0.18), Colors.white),
          Color.alphaBlend(secondary.withValues(alpha: 0.10), Colors.white),
        ],
      );

  Color get border => primary.withValues(alpha: 0.38);
  Color get iconBg => Colors.white.withValues(alpha: 0.22);
  Color get badgeBg => Colors.white.withValues(alpha: 0.24);
  Color get orb => Colors.white.withValues(alpha: 0.16);
  Color get shadow => primary.withValues(alpha: 0.22);
}

abstract final class ClassColorPalette {
  static const _schemes = [
    ClassColorScheme(
      primary: Color(0xFF4F7BF7),
      secondary: Color(0xFF7DA8FF),
      label: 'Blue',
    ),
    ClassColorScheme(
      primary: Color(0xFF9B59F5),
      secondary: Color(0xFFC39BFF),
      label: 'Purple',
    ),
    ClassColorScheme(
      primary: Color(0xFF20BFA8),
      secondary: Color(0xFF5EDFD0),
      label: 'Teal',
    ),
    ClassColorScheme(
      primary: Color(0xFFFF8A4C),
      secondary: Color(0xFFFFB07A),
      label: 'Orange',
    ),
    ClassColorScheme(
      primary: Color(0xFFE85D8A),
      secondary: Color(0xFFFF8FB0),
      label: 'Rose',
    ),
    ClassColorScheme(
      primary: Color(0xFF3ECF8E),
      secondary: Color(0xFF7BE0AE),
      label: 'Green',
    ),
    ClassColorScheme(
      primary: Color(0xFF45C6FF),
      secondary: Color(0xFF84DAFF),
      label: 'Sky',
    ),
    ClassColorScheme(
      primary: Color(0xFF7C8FB0),
      secondary: Color(0xFFA8B5CC),
      label: 'Slate',
    ),
    ClassColorScheme(
      primary: Color(0xFFFFC62E),
      secondary: Color(0xFFFFE082),
      label: 'Gold',
    ),
    ClassColorScheme(
      primary: Color(0xFFB06DFF),
      secondary: Color(0xFFD0A6FF),
      label: 'Lavender',
    ),
  ];

  static ClassColorScheme forClass(int classId) {
    final index = classId.abs() % _schemes.length;
    return _schemes[index];
  }
}

enum ClassColorCardLayout { list, tile }

/// Static decorative circles — welcome-screen style, no animation.
class ClassBubbleDecor extends StatelessWidget {
  const ClassBubbleDecor({
    super.key,
    required this.seed,
    this.compact = false,
  });

  final int seed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : (compact ? 132.0 : 92.0);
        final bubbles = compact
            ? _compactBubbles(seed, w, h)
            : _listBubbles(seed, w, h);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final b in bubbles)
              Positioned(
                left: b.left,
                right: b.right,
                top: b.top,
                bottom: b.bottom,
                child: Container(
                  width: b.d,
                  height: b.d,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: b.alpha),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  static List<_BubbleSpec> _listBubbles(int seed, double w, double h) {
    final shift = (seed.abs() % 3) * 0.04;
    return [
      _BubbleSpec(right: -w * 0.06, top: -h * 0.22, d: 88, alpha: 0.17),
      _BubbleSpec(left: -w * 0.05, bottom: -h * 0.28, d: 72, alpha: 0.14),
      _BubbleSpec(left: w * (0.52 + shift), top: h * 0.02, d: 48, alpha: 0.20),
      _BubbleSpec(right: w * 0.28, top: h * (0.34 + shift), d: 56, alpha: 0.15),
      _BubbleSpec(left: w * 0.14, bottom: h * 0.04, d: 64, alpha: 0.13),
      _BubbleSpec(right: w * 0.12, bottom: h * 0.08, d: 42, alpha: 0.18),
      _BubbleSpec(left: w * 0.68, top: h * 0.18, d: 28, alpha: 0.19),
      _BubbleSpec(right: w * 0.38, top: h * 0.06, d: 24, alpha: 0.16),
      _BubbleSpec(left: w * 0.32, top: h * 0.42, d: 32, alpha: 0.14),
      _BubbleSpec(right: w * 0.06, top: h * 0.48, d: 20, alpha: 0.17),
      _BubbleSpec(left: w * 0.78, bottom: h * 0.12, d: 26, alpha: 0.15),
      _BubbleSpec(left: w * 0.44, top: h * 0.08, d: 18, alpha: 0.12),
    ];
  }

  static List<_BubbleSpec> _compactBubbles(int seed, double w, double h) {
    final shift = (seed.abs() % 3) * 0.05;
    return [
      _BubbleSpec(right: -w * 0.08, top: -h * 0.12, d: 56, alpha: 0.18),
      _BubbleSpec(left: -w * 0.10, bottom: -h * 0.18, d: 44, alpha: 0.14),
      _BubbleSpec(right: w * 0.08, bottom: h * (0.22 + shift), d: 34, alpha: 0.16),
      _BubbleSpec(left: w * 0.12, top: h * 0.28, d: 22, alpha: 0.19),
      _BubbleSpec(right: w * 0.22, top: h * 0.52, d: 16, alpha: 0.14),
      _BubbleSpec(left: w * 0.58, top: h * 0.06, d: 20, alpha: 0.12),
      _BubbleSpec(left: w * 0.72, bottom: h * 0.08, d: 14, alpha: 0.15),
    ];
  }
}

class _BubbleSpec {
  const _BubbleSpec({
    this.left,
    this.right,
    this.top,
    this.bottom,
    required this.d,
    required this.alpha,
  });

  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final double d;
  final double alpha;
}

/// Modern class card tinted by [ClassColorPalette.forClass].
class ClassColorCard extends StatelessWidget {
  const ClassColorCard({
    super.key,
    required this.classId,
    required this.title,
    this.badge,
    this.subtitle,
    this.icon = Icons.class_rounded,
    this.layout = ClassColorCardLayout.list,
    this.onTap,
    this.trailing,
  });

  final int classId;
  /// Raw stored class name (English or Filipino); localized at display time.
  final String title;
  final String? badge;
  final String? subtitle;
  final IconData icon;
  final ClassColorCardLayout layout;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = ClassColorPalette.forClass(classId);
    final app = context.watch<AppState>();
    final displayTitle = app.localizedContent(title);
    final displayBadge =
        badge == null || badge!.isEmpty ? null : app.localizedContent(badge!);
    return layout == ClassColorCardLayout.tile
        ? _TileCard(
            classId: classId,
            colors: colors,
            title: displayTitle,
            badge: displayBadge,
            subtitle: subtitle,
            icon: icon,
            onTap: onTap,
          )
        : _ListCard(
            classId: classId,
            colors: colors,
            title: displayTitle,
            subtitle: subtitle,
            onTap: onTap,
            trailing: trailing,
          );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.classId,
    required this.colors,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  final int classId;
  final ClassColorScheme colors;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 98,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: colors.gradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.antiAlias,
            children: [
              Positioned.fill(
                child: ClassBubbleDecor(seed: classId),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.lg,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.15,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              subtitle!,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.82),
                                height: 1.2,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    ?trailing,
                    if (onTap != null)
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.88),
                        size: 24,
                      ),
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

class _TileCard extends StatelessWidget {
  const _TileCard({
    required this.classId,
    required this.colors,
    required this.title,
    this.badge,
    this.subtitle,
    required this.icon,
    this.onTap,
  });

  final int classId;
  final ClassColorScheme colors;
  final String title;
  final String? badge;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 148,
          height: 148,
          decoration: BoxDecoration(
            gradient: colors.gradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border, width: 1.1),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.antiAlias,
            children: [
              Positioned.fill(
                child: ClassBubbleDecor(seed: classId, compact: true),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colors.iconBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(icon, color: Colors.white, size: 20),
                    ),
                    const Spacer(),
                    if (badge != null && badge!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(
                          badge!,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.78),
                            letterSpacing: 0.3,
                            height: 1.1,
                          ),
                        ),
                      ),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                        letterSpacing: -0.15,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.82),
                          height: 1.25,
                        ),
                      ),
                    ],
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

/// Gradient header with bubble decor for class detail screens.
class ClassColorHeaderBanner extends StatelessWidget {
  const ClassColorHeaderBanner({
    super.key,
    required this.classId,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final int classId;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = ClassColorPalette.forClass(classId);
    final app = context.watch<AppState>();
    final displayTitle = app.localizedContent(title);

    return Container(
      decoration: BoxDecoration(
        gradient: colors.gradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          Positioned.fill(
            child: ClassBubbleDecor(seed: classId),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 6),
                      trailing!,
                    ],
                  ],
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small color dot for inline class labels.
class ClassColorDot extends StatelessWidget {
  const ClassColorDot({super.key, required this.classId, this.size = 10});

  final int classId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = ClassColorPalette.forClass(classId);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: colors.gradient,
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}
