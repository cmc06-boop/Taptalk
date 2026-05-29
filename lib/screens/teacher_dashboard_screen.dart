import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../providers/app_state.dart';
import '../widgets/learner_scaffold.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  int _studentCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final students = await context.read<AppState>().getTeacherClassStudents();
    if (!mounted) return;
    setState(() {
      _studentCount = students.length;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final classCount = app.teacherClasses.length;
    final name = app.user?.fullName ?? '';
    final accent = theme.bgAccent;

    return LearnerScaffold(
      title: AppStrings.appName(lang),
      currentRoute: AppRoute.teacherDashboard,
      showBottomNav: false,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    accent.withValues(alpha: 0.85),
                    const Color(0xFF3ECF8E),
                  ),
                  Color.alphaBlend(
                    accent.withValues(alpha: 0.35),
                    const Color(0xFFB3E6CC),
                  ),
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang == AppLanguage.filipino
                      ? 'Kumusta, $name'
                      : 'Hello, $name',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppStrings.dashboard(lang),
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.teacherDashboardSubtitle(lang),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.88),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -28),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.xxl),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _ModernStatCard(
                            theme: theme,
                            label: AppStrings.totalClasses(lang),
                            value: '$classCount',
                            icon: Icons.class_rounded,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _ModernStatCard(
                            theme: theme,
                            label: AppStrings.totalStudents(lang),
                            value: '$_studentCount',
                            icon: Icons.groups_rounded,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  lang == AppLanguage.filipino
                      ? 'Mabilis na aksyon'
                      : 'Quick actions',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: theme.textMain,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _QuickActionCard(
                  theme: theme,
                  icon: Icons.class_rounded,
                  title: AppStrings.myClasses(lang),
                  subtitle: lang == AppLanguage.filipino
                      ? 'Gumawa at pamahalaan ang mga klase'
                      : 'Create and manage your classes',
                  accent: accent,
                  onTap: () => app.setRoute(AppRoute.teacherMyClasses),
                ),
                const SizedBox(height: AppSpacing.sm),
                _QuickActionCard(
                  theme: theme,
                  icon: Icons.monitor_heart_rounded,
                  title: AppStrings.monitoring(lang),
                  subtitle: AppStrings.teacherMonitoringSubtitle(lang),
                  accent: accent,
                  onTap: () => app.setRoute(AppRoute.teacherMonitoring),
                ),
                const SizedBox(height: AppSpacing.sm),
                _QuickActionCard(
                  theme: theme,
                  icon: Icons.chat_bubble_outline_rounded,
                  title: AppStrings.forMe(lang),
                  subtitle: lang == AppLanguage.filipino
                      ? 'Personal na phrase board'
                      : 'Your personal phrase board',
                  accent: accent,
                  onTap: () => app.setRoute(AppRoute.home),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernStatCard extends StatelessWidget {
  const _ModernStatCard({
    required this.theme,
    required this.label,
    required this.value,
    required this.icon,
  });

  final TapTalkThemeToken theme;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: theme.textMain.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.bgAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.bgAccent, size: 22),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: theme.textMain,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.textMain.withValues(alpha: 0.58),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.theme,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final TapTalkThemeToken theme;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE9EEF2)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.22),
                      accent.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: theme.textMain.withValues(alpha: 0.58),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.textMain.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
