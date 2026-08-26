import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../data/models/class_join_request.dart';
import '../providers/app_state.dart';
import '../widgets/app_header.dart';
import '../widgets/localized_content_text.dart';
import '../widgets/learner_scaffold.dart';
import '../widgets/taptalk_result_dialog.dart';

class TeacherJoinRequestsScreen extends StatefulWidget {
  const TeacherJoinRequestsScreen({super.key});

  @override
  State<TeacherJoinRequestsScreen> createState() =>
      _TeacherJoinRequestsScreenState();
}

class _TeacherJoinRequestsScreenState extends State<TeacherJoinRequestsScreen> {
  int? _busyRequestId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refreshPendingJoinRequests(
            cloudSyncInBackground: false,
          );
    });
  }

  Future<void> _accept(ClassJoinRequest request) async {
    if (_busyRequestId != null) return;
    setState(() => _busyRequestId = request.id);
    final app = context.read<AppState>();
    final lang = app.language;
    final error = await app.acceptJoinRequest(request.id);
    if (!mounted) return;
    setState(() => _busyRequestId = null);
    if (error != null) {
      await TapTalkResultDialog.showError(
        context,
        title: AppStrings.somethingWentWrong(lang),
        message: error,
      );
      return;
    }
    await TapTalkResultDialog.showSuccess(
      context,
      title: AppStrings.joinRequestAcceptedTitle(lang),
      message: AppStrings.joinRequestAccepted(lang, request.learnerName),
    );
  }

  Future<void> _reject(ClassJoinRequest request) async {
    if (_busyRequestId != null) return;
    setState(() => _busyRequestId = request.id);
    final app = context.read<AppState>();
    final lang = app.language;
    final error = await app.rejectJoinRequest(request.id);
    if (!mounted) return;
    setState(() => _busyRequestId = null);
    if (error != null) {
      await TapTalkResultDialog.showError(
        context,
        title: AppStrings.somethingWentWrong(lang),
        message: error,
      );
      return;
    }
    await TapTalkResultDialog.showSuccess(
      context,
      title: AppStrings.joinRequestRejectedTitle(lang),
      message: AppStrings.joinRequestRejected(lang, request.learnerName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final requests = app.pendingJoinRequests;

    return LearnerScaffold(
      title: AppStrings.joinRequests(lang),
      titleWidget: AppHeaderTitle(AppStrings.joinRequests(lang)),
      currentRoute: AppRoute.teacherJoinRequests,
      headerContentHeight: AppHeaderTitle.height,
      headerBottomSpacing: 0,
      bodyTopOffset: -4,
      showBottomNav: false,
      body: RefreshIndicator(
        onRefresh: () => app.refreshPendingJoinRequests(
          cloudSyncInBackground: false,
        ),
        color: theme.bgAccent,
        child: requests.isEmpty
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
                              AppStrings.noJoinRequests(lang),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: theme.textMain.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                children: [
                  for (final request in requests)
                    Padding(
                      key: ValueKey(
                        'join_req_${request.id}_${app.joinRequestsRevision}',
                      ),
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _JoinRequestCard(
                        request: request,
                        theme: theme,
                        lang: lang,
                        busy: _busyRequestId == request.id,
                        onAccept: () => _accept(request),
                        onReject: () => _reject(request),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _JoinRequestCard extends StatelessWidget {
  const _JoinRequestCard({
    required this.request,
    required this.theme,
    required this.lang,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });

  final ClassJoinRequest request;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  String _compactRequestTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}hr';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${date.month}/${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EEF2)),
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
          Expanded(
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 38,
                    decoration: BoxDecoration(
                      color: theme.bgAccent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                      color: theme.bgAccent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.learnerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: theme.textMain,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.bgAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: LocalizedContentText(
                            request.className,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.bgAccent,
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
          const SizedBox(width: AppSpacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _compactRequestTime(request.requestedAt),
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: theme.textMain.withValues(alpha: 0.38),
                  height: 1,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    onPressed: busy ? null : onReject,
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          const Color(0xFFC62828).withValues(alpha: 0.1),
                      foregroundColor: const Color(0xFFC62828),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      AppStrings.rejectRequest(lang),
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  FilledButton(
                    onPressed: busy ? null : onAccept,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.bgAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      AppStrings.acceptRequest(lang),
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
