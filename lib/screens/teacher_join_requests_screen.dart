import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../data/models/class_join_request.dart';
import '../providers/app_state.dart';
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
      currentRoute: AppRoute.teacherJoinRequests,
      showBottomNav: false,
      body: RefreshIndicator(
        onRefresh: () => app.refreshPendingJoinRequests(
          cloudSyncInBackground: false,
        ),
        color: theme.bgAccent,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          children: [
            Text(
              AppStrings.joinRequestsSubtitle(lang),
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: theme.textMain.withValues(alpha: 0.65),
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (requests.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xxl),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE9EEF2)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.person_add_alt_1_outlined,
                      size: 48,
                      color: theme.bgAccent.withValues(alpha: 0.55),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      AppStrings.noJoinRequests(lang),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: theme.textMain.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              )
            else
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.bgAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person_outline_rounded, color: theme.bgAccent),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.learnerNameLabel(lang),
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.textMain.withValues(alpha: 0.55),
                      ),
                    ),
                    Text(
                      request.learnerName,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.textMain,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            AppStrings.subjectLabel(lang),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.textMain.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 2),
          LocalizedContentText(
            request.className,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.textMain.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC62828),
                    side: BorderSide(
                      color: const Color(0xFFC62828).withValues(alpha: 0.35),
                    ),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: busy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.bgAccent,
                          ),
                        )
                      : Text(
                          AppStrings.rejectRequest(lang),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onAccept,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.bgAccent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    AppStrings.acceptRequest(lang),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
