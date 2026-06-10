import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../data/models/linked_child_model.dart';
import '../data/models/monitored_learner.dart';
import '../providers/app_state.dart';
import '../widgets/learner_scaffold.dart';
import '../widgets/link_child_dialog.dart';
import '../widgets/taptalk_result_dialog.dart';
import 'child_monitoring_screen.dart';

class MyChildScreen extends StatefulWidget {
  const MyChildScreen({super.key});

  @override
  State<MyChildScreen> createState() => _MyChildScreenState();
}

class _MyChildScreenState extends State<MyChildScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refreshLinkedChildren(
            cloudSyncInBackground: true,
          );
    });
  }

  Future<void> _refresh(BuildContext context) async {
    await context.read<AppState>().refreshLinkedChildren(
          cloudSyncInBackground: false,
        );
  }

  Future<void> _showLinkChildDialog(BuildContext context) async {
    await LinkChildDialog.show(context);
  }

  void _openMonitoring(BuildContext context, LinkedChildModel child) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChildMonitoringScreen(
          learner: MonitoredLearner.fromLinkedChild(child),
        ),
      ),
    );
  }

  Future<void> _confirmUnlink(
    BuildContext context,
    LinkedChildModel child,
  ) async {
    final app = context.read<AppState>();
    final lang = app.language;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(AppStrings.unlinkChildConfirm(lang, child.fullName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel(lang)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.unlinkChild(lang)),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    await app.unlinkChild(child.learnerId);
    if (!context.mounted) return;
    await TapTalkResultDialog.showSuccess(
      context,
      title: AppStrings.childUnlinkedTitle(lang),
      message: AppStrings.childUnlinked(lang),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = app.theme;
    final lang = app.language;
    final children = app.linkedChildren;

    return LearnerScaffold(
      title: AppStrings.appName(lang),
      currentRoute: AppRoute.myChild,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => _refresh(context),
            color: theme.bgAccent,
            child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: 88,
            ),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.bgMid.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.myChild(lang),
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: theme.textMain,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      AppStrings.myChildSubtitle(lang),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: theme.textMain.withValues(alpha: 0.72),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (children.isEmpty)
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.4,
                  child: Center(
                    child: Text(
                      AppStrings.noLinkedChild(lang),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: theme.textMain.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                )
              else
                ...children.map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _LinkedChildTile(
                      child: child,
                      theme: theme,
                      lang: lang,
                      onOpen: () => _openMonitoring(context, child),
                      onUnlink: () => _confirmUnlink(context, child),
                    ),
                  ),
                ),
            ],
            ),
          ),
          Positioned(
            right: AppSpacing.lg,
            bottom: AppSpacing.md,
            child: FloatingActionButton(
              onPressed: () => _showLinkChildDialog(context),
              backgroundColor: theme.bgAccent,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkedChildTile extends StatelessWidget {
  const _LinkedChildTile({
    required this.child,
    required this.theme,
    required this.lang,
    required this.onOpen,
    required this.onUnlink,
  });

  final LinkedChildModel child;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final VoidCallback onOpen;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9EEF2)),
        boxShadow: [
          BoxShadow(
            color: theme.textMain.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.bgAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.child_care_outlined,
                          color: theme.bgAccent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              child.fullName,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: theme.textMain,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppStrings.viewMonitoring(lang),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: theme.bgAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Flexible(
              child: TextButton(
                onPressed: onUnlink,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.sm,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  AppStrings.unlinkChild(lang),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.bgAccent,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: onOpen,
              behavior: HitTestBehavior.opaque,
              child: Icon(
                Icons.chevron_right_rounded,
                color: theme.textMain.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
