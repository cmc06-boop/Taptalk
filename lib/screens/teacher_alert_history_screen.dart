import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../data/models/teacher_recent_alert.dart';
import '../providers/app_state.dart';
import '../widgets/learner_scaffold.dart';
import '../widgets/teacher_alert_card.dart';

class TeacherAlertHistoryScreen extends StatefulWidget {
  const TeacherAlertHistoryScreen({super.key});

  @override
  State<TeacherAlertHistoryScreen> createState() =>
      _TeacherAlertHistoryScreenState();
}

class _TeacherAlertHistoryScreenState extends State<TeacherAlertHistoryScreen> {
  List<TeacherRecentAlert> _alerts = [];
  bool _loading = true;
  int _lastAlertsRevision = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revision = context.read<AppState>().teacherAlertsRevision;
    if (revision != _lastAlertsRevision) {
      _lastAlertsRevision = revision;
      if (revision > 0) {
        unawaited(_load());
      }
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final alerts = await context.read<AppState>().getTeacherAlertHistory();
    if (!mounted) return;
    setState(() {
      _alerts = alerts;
      _loading = false;
    });
  }

  static String _sectionLabel(DateTime date, AppLanguage lang) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    if (day == today) return AppStrings.todayLabel(lang);
    if (day == today.subtract(const Duration(days: 1))) {
      return AppStrings.yesterdayLabel(lang);
    }
    final locale = lang == AppLanguage.filipino ? 'fil_PH' : 'en_US';
    return DateFormat.yMMMMd(locale).format(date);
  }

  static Map<String, List<TeacherRecentAlert>> _groupBySection(
    List<TeacherRecentAlert> items,
    AppLanguage lang,
  ) {
    final grouped = <String, List<TeacherRecentAlert>>{};
    for (final item in items) {
      final key = _sectionLabel(item.createdAt, lang);
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final grouped = _groupBySection(_alerts, lang);
    final sectionKeys = grouped.keys.toList();

    return LearnerScaffold(
      title: AppStrings.alertHistory(lang),
      currentRoute: AppRoute.teacherAlertHistory,
      showBackButton: true,
      showBottomNav: false,
      onBack: () => app.setRoute(AppRoute.teacherDashboard),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              AppStrings.alertHistorySubtitle(lang),
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: theme.textMain.withValues(alpha: 0.65),
                height: 1.35,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: theme.bgAccent),
                  )
                : _alerts.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xxl),
                          child: Text(
                            AppStrings.noRecentAlerts(lang),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: theme.textMain.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: theme.bgAccent,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                          itemCount: sectionKeys.length,
                          itemBuilder: (context, sectionIndex) {
                            final section = sectionKeys[sectionIndex];
                            final sectionItems = grouped[section]!;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.lg,
                                    AppSpacing.md,
                                    AppSpacing.lg,
                                    AppSpacing.sm,
                                  ),
                                  child: Text(
                                    section,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: theme.textMain.withValues(alpha: 0.55),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                                for (final alert in sectionItems)
                                  Padding(
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
                                      timeLabel: AppStrings.timeAgo(
                                        alert.createdAt,
                                        lang,
                                      ),
                                      description: AppStrings.alertTypeLabel(
                                        lang,
                                        alert.alertType,
                                      ),
                                      className: app.localizedContent(alert.className),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
