import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/utils/parent_alert_icons.dart';
import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../data/models/parent_notification.dart';
import '../providers/app_state.dart';
import '../widgets/learner_scaffold.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refreshNotifications();
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

  static Map<String, List<ParentNotification>> _groupBySection(
    List<ParentNotification> items,
    AppLanguage lang,
  ) {
    final grouped = <String, List<ParentNotification>>{};
    for (final item in items) {
      final key = _sectionLabel(item.createdAt, lang);
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped;
  }

  static String _formatTime(DateTime date, AppLanguage lang) {
    return DateFormat.jm(
      lang == AppLanguage.filipino ? 'fil_PH' : 'en_US',
    ).format(date);
  }

  static IconData _iconFor(ParentAlertType type) =>
      ParentAlertIcons.forType(type);

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final items = app.notifications;
    final grouped = _groupBySection(items, lang);
    final sectionKeys = grouped.keys.toList();

    return LearnerScaffold(
      title: AppStrings.notifications(lang),
      currentRoute: AppRoute.notifications,
      showBackButton: true,
      showBottomNav: false,
      onBack: () => app.setRoute(AppRoute.home),
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
              AppStrings.notificationsSubtitle(lang),
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: theme.textMain.withValues(alpha: 0.65),
                height: 1.35,
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Text(
                        AppStrings.noNotifications(lang),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: theme.textMain.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
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
                            child: Row(
                              children: [
                                Expanded(
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
                                if (sectionIndex == 0 && app.unreadNotificationCount > 0)
                                  TextButton(
                                    onPressed: () => app.markAllNotificationsRead(),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      AppStrings.markAllRead(lang),
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: theme.bgAccent,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          for (final notification in sectionItems)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg,
                                0,
                                AppSpacing.lg,
                                AppSpacing.sm,
                              ),
                              child: _NotificationTile(
                                notification: notification,
                                theme: theme,
                                lang: lang,
                                timeLabel: _formatTime(
                                  notification.createdAt,
                                  lang,
                                ),
                                icon: _iconFor(notification.alertType),
                                onTap: () =>
                                    app.markNotificationRead(notification.id),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.theme,
    required this.lang,
    required this.timeLabel,
    required this.icon,
    required this.onTap,
  });

  final ParentNotification notification;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final String timeLabel;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    final accent = theme.bgAccent;

    final cardFill = unread
        ? Color.alphaBlend(
            accent.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.96),
          )
        : Color.alphaBlend(
            theme.bgLight.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.94),
          );

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: cardFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: unread
                  ? accent.withValues(alpha: 0.22)
                  : const Color(0xFFE9EEF2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.textMain.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: unread
                          ? accent.withValues(alpha: 0.18)
                          : theme.bgMid.withValues(alpha: 0.65),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: unread ? accent : theme.textMain,
                    ),
                  ),
                  if (unread)
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.bgLight, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight:
                                  unread ? FontWeight.w700 : FontWeight.w600,
                              color: theme.textMain,
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          timeLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: theme.textMain.withValues(
                              alpha: unread ? 0.72 : 0.48,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (unread) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              AppStrings.newAlertBadge(lang),
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE8E8),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              AppStrings.urgentLabel(lang),
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFC62828),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            notification.childName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: theme.textMain.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight:
                            unread ? FontWeight.w500 : FontWeight.w400,
                        color: theme.textMain.withValues(
                          alpha: unread ? 0.82 : 0.62,
                        ),
                        height: 1.35,
                      ),
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

