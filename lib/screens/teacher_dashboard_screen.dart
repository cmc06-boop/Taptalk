import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/utils/live_refresh.dart';
import '../core/theme/theme_tokens.dart';
import '../core/utils/class_name_utils.dart';
import '../data/models/teacher_recent_alert.dart';
import '../data/models/teacher_recent_lesson.dart';
import '../providers/app_state.dart';
import '../widgets/class_color_card.dart';
import '../widgets/inline_dropdown_field.dart';
import '../widgets/learner_scaffold.dart';
import '../widgets/teacher_alert_card.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  List<TeacherRecentAlert> _recentAlerts = [];
  List<TeacherRecentLesson> _recentLessons = [];
  String? _selectedSubject;
  bool _loadingFeed = true;
  int _lastAlertsRevision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load(refreshClasses: true);
    });
  }

  bool _sameAlerts(List<TeacherRecentAlert> a, List<TeacherRecentAlert> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].alertType != b[i].alertType ||
          a[i].childName != b[i].childName ||
          a[i].className != b[i].className) {
        return false;
      }
    }
    return true;
  }

  bool _sameLessons(List<TeacherRecentLesson> a, List<TeacherRecentLesson> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].title != b[i].title ||
          a[i].className != b[i].className ||
          a[i].phraseCount != b[i].phraseCount) {
        return false;
      }
    }
    return true;
  }

  List<String> _subjectsFor(AppState app) {
    final subjects = app.teacherClasses
        .map((c) => ClassNameUtils.subjectFrom(c.name))
        .toSet()
        .toList()
      ..sort();
    return subjects;
  }

  Map<String, int> _subjectStudentCountsFor(AppState app) {
    final classIdsBySubject = <String, List<int>>{};
    for (final teacherClass in app.teacherClasses) {
      final subject = ClassNameUtils.subjectFrom(teacherClass.name);
      classIdsBySubject.putIfAbsent(subject, () => []).add(teacherClass.id);
    }
    final subjectStudentCounts = <String, int>{};
    for (final entry in classIdsBySubject.entries) {
      var total = 0;
      for (final classId in entry.value) {
        total += app.teacherClassStudentCount(classId);
      }
      subjectStudentCounts[entry.key] = total;
    }
    return subjectStudentCounts;
  }

  Future<void> _load({
    bool userRefresh = false,
    bool refreshClasses = false,
  }) async {
    final app = context.read<AppState>();
    try {
      if (userRefresh || refreshClasses) {
        await app.refreshTeacherClasses(cloudSyncInBackground: !userRefresh);
      }

      final showSpinner =
          userRefresh || (_recentAlerts.isEmpty && _recentLessons.isEmpty);
      if (showSpinner && mounted) {
        setState(() => _loadingFeed = true);
      }

      final results = await Future.wait([
        app.getTeacherRecentAlerts(),
        app.getTeacherRecentLessons(),
      ]);
      if (!mounted) return;

      final alerts = results[0] as List<TeacherRecentAlert>;
      final lessons = results[1] as List<TeacherRecentLesson>;
      if (_sameAlerts(_recentAlerts, alerts) &&
          _sameLessons(_recentLessons, lessons)) {
        if (_loadingFeed && mounted) {
          setState(() => _loadingFeed = false);
        }
        return;
      }

      setState(() {
        _recentAlerts = alerts;
        _recentLessons = lessons;
        _loadingFeed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingFeed = false);
    }
  }

  int _classCountForFilter(AppState app, String? selectedSubject) {
    if (selectedSubject == null) return app.teacherClasses.length;
    return app.teacherClasses
        .where(
          (c) => ClassNameUtils.subjectFrom(c.name) == selectedSubject,
        )
        .length;
  }

  int _studentCountForFilter(AppState app, Map<String, int> subjectStudentCounts) {
    if (_selectedSubject == null) return app.teacherStudentCount;
    return subjectStudentCounts[_selectedSubject] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    _lastAlertsRevision = bindLiveRevision(
      lastRevision: _lastAlertsRevision,
      currentRevision: app.teacherAlertsRevision,
      reload: _load,
      isMounted: () => mounted,
    );
    final theme = app.theme;
    final lang = app.language;
    final subjects = _subjectsFor(app);
    final subjectStudentCounts = _subjectStudentCountsFor(app);
    final selectedSubject =
        _selectedSubject != null && subjects.contains(_selectedSubject)
            ? _selectedSubject
            : null;
    final classCount = _classCountForFilter(app, selectedSubject);
    final studentCount = _studentCountForFilter(app, subjectStudentCounts);
    final accent = theme.bgAccent;

    return LearnerScaffold(
      title: AppStrings.appName(lang),
      currentRoute: AppRoute.teacherDashboard,
      showBottomNav: false,
      body: RefreshIndicator(
        onRefresh: () => _load(userRefresh: true),
        color: accent,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent,
                    Color.lerp(accent, theme.bgMid, 0.45) ?? theme.bgMid,
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
                  const SizedBox(height: AppSpacing.lg),
                  IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _ClassesStatCard(
                            theme: theme,
                            label: AppStrings.totalClasses(lang),
                            value: '$classCount',
                            subjects: subjects,
                            selectedSubject: selectedSubject,
                            allSubjectsLabel: AppStrings.allSubjects(lang),
                            subjectLabel: app.localizedContent,
                            onSubjectChanged: (value) =>
                                setState(() => _selectedSubject = value),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _ModernStatCard(
                              theme: theme,
                              label: AppStrings.totalStudents(lang),
                              value: '$studentCount',
                              icon: Icons.groups_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            _SectionHeader(
              theme: theme,
              title: AppStrings.recentAlerts(lang),
              actionLabel: AppStrings.viewAll(lang),
              onAction: () => app.setRoute(AppRoute.teacherAlertHistory),
            ),
            if (_loadingFeed)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_recentAlerts.isEmpty)
              _EmptySectionCard(
                theme: theme,
                message: AppStrings.noRecentAlerts(lang),
                icon: Icons.notifications_none_rounded,
              )
            else
              ..._recentAlerts.map(
                (alert) => Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: TeacherAlertCard(
                    theme: theme,
                    alertType: alert.alertType,
                    studentName: alert.childName.trim(),
                    timeLabel: AppStrings.timeAgo(alert.createdAt, lang),
                    description: AppStrings.alertTypeLabel(lang, alert.alertType),
                    onTap: () => app.setRoute(AppRoute.teacherAlertHistory),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            _SectionHeader(
              theme: theme,
              title: AppStrings.recentLessons(lang),
              actionLabel: AppStrings.viewAll(lang),
              onAction: () => app.setRoute(AppRoute.teacherMyClasses),
            ),
            if (_loadingFeed)
              const SizedBox.shrink()
            else if (_recentLessons.isEmpty)
              _EmptySectionCard(
                theme: theme,
                message: AppStrings.noRecentLessons(lang),
                icon: Icons.menu_book_outlined,
              )
            else
              SizedBox(
                height: 168,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  itemCount: _recentLessons.length,
                  separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final lesson = _recentLessons[index];
                    return ClassColorCard(
                      classId: lesson.classId,
                      title: lesson.title,
                      badge: lesson.className,
                      subtitle:
                          '${AppStrings.phrasesCount(lesson.phraseCount, lang)} · ${AppStrings.timeAgo(lesson.createdAt, lang)}',
                      icon: Icons.auto_stories_rounded,
                      layout: ClassColorCardLayout.tile,
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                lang == AppLanguage.filipino
                    ? 'Mabilis na aksyon'
                    : 'Quick actions',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: theme.textMain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.theme,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final TapTalkThemeToken theme;
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: theme.textMain,
              ),
            ),
          ),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.bgAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySectionCard extends StatelessWidget {
  const _EmptySectionCard({
    required this.theme,
    required this.message,
    required this.icon,
  });

  final TapTalkThemeToken theme;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.bgMid.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EEF2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.textMain.withValues(alpha: 0.35), size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: theme.textMain.withValues(alpha: 0.68),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassesStatCard extends StatefulWidget {
  const _ClassesStatCard({
    required this.theme,
    required this.label,
    required this.value,
    required this.subjects,
    required this.selectedSubject,
    required this.allSubjectsLabel,
    required this.subjectLabel,
    required this.onSubjectChanged,
  });

  final TapTalkThemeToken theme;
  final String label;
  final String value;
  final List<String> subjects;
  final String? selectedSubject;
  final String allSubjectsLabel;
  final String Function(String text) subjectLabel;
  final ValueChanged<String?> onSubjectChanged;

  @override
  State<_ClassesStatCard> createState() => _ClassesStatCardState();
}

class _ClassesStatCardState extends State<_ClassesStatCard> {
  String _displaySubject(String? subject) {
    if (subject == null) return widget.allSubjectsLabel;
    return widget.subjectLabel(subject);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final subjectOptions = <String?>[null, ...widget.subjects];

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
        mainAxisSize: MainAxisSize.max,
        children: [
          _StatValueIconRow(
            theme: theme,
            value: widget.value,
            icon: Icons.class_rounded,
          ),
          const SizedBox(height: 4),
          Text(
            widget.label,
            textAlign: TextAlign.left,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.textMain.withValues(alpha: 0.58),
            ),
          ),
          if (widget.subjects.isNotEmpty) ...[
            const Spacer(),
            const SizedBox(height: AppSpacing.sm),
            InlineDropdownField<String?>(
              overlayMenu: true,
              value: _displaySubject(widget.selectedSubject),
              options: subjectOptions,
              optionLabel: _displaySubject,
              selected: widget.selectedSubject,
              theme: theme,
              maxMenuHeight: 140,
              onSelected: widget.onSubjectChanged,
            ),
          ],
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
        mainAxisSize: MainAxisSize.max,
        children: [
          _StatValueIconRow(theme: theme, value: value, icon: icon),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.left,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.textMain.withValues(alpha: 0.58),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _StatValueIconRow extends StatelessWidget {
  const _StatValueIconRow({
    required this.theme,
    required this.value,
    required this.icon,
  });

  final TapTalkThemeToken theme;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
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
          textAlign: TextAlign.left,
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: theme.textMain,
            height: 1,
          ),
        ),
      ],
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
