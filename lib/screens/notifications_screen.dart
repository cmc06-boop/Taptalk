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
import '../widgets/app_header.dart';
import '../widgets/learner_scaffold.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<ParentNotification> _teacherAlertRecords = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  Future<void> _refresh() async {
    final app = context.read<AppState>();
    await app.refreshNotifications();
    if (!mounted) return;
    final teacherRecords = await _loadTeacherAlertRecords(app);
    if (!mounted) return;
    setState(() => _teacherAlertRecords = teacherRecords);
  }

  Future<List<ParentNotification>> _loadTeacherAlertRecords(
    AppState app,
  ) async {
    if (app.user?.isTeacher != true) return const [];
    final lang = app.language;
    final teacherId = app.user!.id;
    final alerts = await app.getTeacherAlertHistory();
    return [
      for (final alert in alerts)
        ParentNotification(
          id: alert.id,
          parentUserId: teacherId,
          childName: alert.childName,
          alertType: alert.alertType,
          title: alert.childName.trim().isEmpty
              ? AppStrings.alertTypeLabel(lang, alert.alertType)
              : alert.childName.trim(),
          body: AppStrings.alertTypeLabel(lang, alert.alertType),
          createdAt: alert.createdAt,
          isRead: true,
        ),
    ];
  }

  List<ParentNotification> _mergedItems(List<ParentNotification> inbox) {
    if (_teacherAlertRecords.isEmpty) return inbox;
    final byId = <int, ParentNotification>{
      for (final item in inbox) item.id: item,
    };
    for (final item in _teacherAlertRecords) {
      byId.putIfAbsent(item.id, () => item);
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  static String _displayTitle(String title) {
    return title
        .replaceFirst(
          RegExp(r'^Level\s+[123]\s*[–\-]\s*', caseSensitive: false),
          '',
        )
        .trim();
  }

  static String _displayBody(String body) {
    var text = body.trim().split(RegExp(r'\n\s*\n')).first.trim();
    text = text.replaceAll(
      RegExp(
        r'\s*(This phrase has reached the daily attention threshold\.?'
        r'|This phrase reached the attention threshold[^\n]*'
        r'|Naabot ng pariralang ito ang arawang attention threshold\.?'
        r'|Naabot ulit ng pariralang ito[^\n]*'
        r'|Naabot ng pariralang ito ang attention threshold sa loob[^\n]*)',
        caseSensitive: false,
      ),
      '',
    );
    return text.trim();
  }

  static bool _isUsageWarningNotification(ParentNotification notification) {
    final title = _displayTitle(notification.title).toLowerCase();
    if (title == 'needs attention' ||
        title == 'persistent pattern' ||
        title == 'needs review' ||
        title == 'warning' ||
        title == 'babala') {
      return true;
    }
    final body = notification.body.toLowerCase();
    return body.contains('times today') ||
        body.contains('beses ngayon') ||
        body.contains('has used') ||
        body.contains('ay nagamit ng');
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

  static Future<void> _showNotificationDetail(
    BuildContext context, {
    required ParentNotification notification,
    required TapTalkThemeToken theme,
    required AppLanguage lang,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: theme.textMain.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Center(
          child: _NotificationDetailPopup(
            notification: notification,
            theme: theme,
            lang: lang,
            title: _displayTitle(notification.title),
            body: _displayBody(notification.body),
            showTypeLabel: !_isUsageWarningNotification(notification),
            timeLabel: _formatTime(notification.createdAt, lang),
            icon: _iconFor(notification.alertType),
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final items = _mergedItems(app.notifications);
    final grouped = _groupBySection(items, lang);
    final sectionKeys = grouped.keys.toList();

    return LearnerScaffold(
      title: AppStrings.notifications(lang),
      titleWidget: AppHeaderTitle(AppStrings.notifications(lang)),
      currentRoute: AppRoute.notifications,
      headerContentHeight: AppHeaderTitle.height,
      headerBottomSpacing: 0,
      bodyTopOffset: -4,
      showBottomNav: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: theme.bgAccent,
              child: items.isEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: constraints.maxHeight,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xl,
                                  ),
                                  child: Text(
                                    AppStrings.noNotifications(lang),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: theme.textMain.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    section,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: theme.textMain.withValues(
                                        alpha: 0.55,
                                      ),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  if (sectionIndex == 0 &&
                                      app.unreadNotificationCount > 0)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () =>
                                            app.markAllNotificationsRead(),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          AppStrings.markAllRead(lang),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: theme.bgAccent,
                                          ),
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
                                  title: _displayTitle(notification.title),
                                  body: _displayBody(notification.body),
                                  timeLabel: _formatTime(
                                    notification.createdAt,
                                    lang,
                                  ),
                                  icon: _iconFor(notification.alertType),
                                  onTap: app.user?.isTeacher == true
                                      ? null
                                      : () async {
                                          await app.markNotificationRead(
                                            notification.id,
                                          );
                                          if (!context.mounted) return;
                                          await _showNotificationDetail(
                                            context,
                                            notification: notification,
                                            theme: theme,
                                            lang: lang,
                                          );
                                        },
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

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.theme,
    required this.lang,
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.icon,
    this.onTap,
  });

  final ParentNotification notification;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final String title;
  final String body;
  final String timeLabel;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    final accent = theme.bgAccent;
    final alertColor = ParentAlertIcons.iconColor(notification.alertType);
    final alertBg = ParentAlertIcons.iconBackground(notification.alertType);

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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: alertBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 19, color: alertColor),
                  ),
                  if (unread)
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: alertColor,
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
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: theme.textMain,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 6),
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
                                height: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
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
                                height: 1,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          timeLabel,
                          maxLines: 1,
                          softWrap: false,
                          textAlign: TextAlign.end,
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
                    SizedBox(
                      height: 30,
                      child: Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: unread
                              ? FontWeight.w500
                              : FontWeight.w400,
                          color: theme.textMain.withValues(
                            alpha: unread ? 0.82 : 0.62,
                          ),
                          height: 1.25,
                        ),
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

class _NotificationDetailPopup extends StatelessWidget {
  const _NotificationDetailPopup({
    required this.notification,
    required this.theme,
    required this.lang,
    required this.title,
    required this.body,
    required this.showTypeLabel,
    required this.timeLabel,
    required this.icon,
    required this.onClose,
  });

  final ParentNotification notification;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final String title;
  final String body;
  final bool showTypeLabel;
  final String timeLabel;
  final IconData icon;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final accent = theme.bgAccent;
    final iconColor = ParentAlertIcons.iconColor(notification.alertType);
    final iconBg = ParentAlertIcons.iconBackground(notification.alertType);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 420, maxHeight: maxHeight),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE9EEF2)),
              boxShadow: [
                BoxShadow(
                  color: theme.textMain.withValues(alpha: 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.md,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: iconBg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, size: 24, color: iconColor),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: theme.textMain,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                timeLabel,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: theme.textMain.withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: onClose,
                          icon: Icon(
                            Icons.close_rounded,
                            color: theme.textMain.withValues(alpha: 0.45),
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showTypeLabel) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: Text(
                        AppStrings.alertTypeLabel(lang, notification.alertType),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: iconColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ] else
                    const SizedBox(height: AppSpacing.md),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.md,
                      ),
                      child: Text(
                        body,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.textMain.withValues(alpha: 0.82),
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: FilledButton(
                      onPressed: onClose,
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        AppStrings.ok(lang),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
