import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/utils/live_refresh.dart';
import '../core/constants/app_spacing.dart';
import '../core/navigation/route_transitions.dart';
import '../core/l10n/app_strings.dart';
import '../core/theme/theme_tokens.dart';
import '../data/models/linked_child_model.dart';
import '../data/models/monitored_learner.dart';
import '../providers/app_state.dart';
import '../services/caregiver_access.dart';
import '../services/caregiver_security_service.dart';
import '../widgets/caregiver_transfer_flow.dart';
import '../widgets/compact_popup_menu.dart';
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
  int _lastLiveRevision = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refreshCaregiverAccess();
    });
  }

  Future<void> _refresh(BuildContext context) async {
    await context.read<AppState>().refreshCaregiverAccess();
  }

  Future<void> _showLinkChildDialog(BuildContext context) async {
    await LinkChildDialog.show(context);
  }

  void _openMonitoring(BuildContext context, LinkedChildModel child) {
    Navigator.of(context).push(
      taptalkPageRoute<void>(
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
    final error = await app.unlinkChild(child.learnerId);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await TapTalkResultDialog.showSuccess(
      context,
      title: AppStrings.childUnlinkedTitle(lang),
      message: AppStrings.childUnlinked(lang),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    _lastLiveRevision = bindLiveRevision(
      lastRevision: _lastLiveRevision,
      currentRevision: app.liveDataRevision,
      reload: () => _refresh(context),
      isMounted: () => mounted,
    );
    final theme = app.theme;
    final lang = app.language;
    final children = app.linkedChildren;

    return LearnerScaffold(
      title: AppStrings.myChild(lang),
      titleWidget: SizedBox(
        height: 85,
        child: Center(
          child: Text(
            AppStrings.myChild(lang),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: theme.textMain,
            ),
          ),
        ),
      ),
      currentRoute: AppRoute.myChild,
      headerContentHeight: 85,
      headerBottomSpacing: 0,
      bodyTopOffset: -4,
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
                top: AppSpacing.md,
                bottom: 88,
              ),
              children: [..._accessCards(context, app, theme, lang, children)],
            ),
          ),
          if (app.caregiverAccess != CaregiverAccess.verifyDevice &&
              app.caregiverAccess != CaregiverAccess.legacy)
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

  List<Widget> _accessCards(
    BuildContext context,
    AppState app,
    TapTalkThemeToken theme,
    AppLanguage lang,
    List<LinkedChildModel> children,
  ) {
    switch (app.caregiverAccess) {
      case CaregiverAccess.verifyDevice:
        return [
          _AccessMessage(
            theme: theme,
            title: AppStrings.verifyThisDeviceBody(lang),
          ),
        ];
      case CaregiverAccess.legacy:
        return [
          _LegacyLinksPanel(
            theme: theme,
            lang: lang,
            learners: app.legacyLearners,
          ),
        ];
      // Untrusted phones never reach this screen (the device gate covers the
      // app), so a pending or offline check simply shows the saved list.
      case CaregiverAccess.unknown:
      case CaregiverAccess.unavailable:
      case CaregiverAccess.setup:
      case CaregiverAccess.trusted:
        if (children.isEmpty) {
          return [
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
            ),
          ];
        }
        return [
          for (final child in children)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _LinkedChildTile(
                child: child,
                theme: theme,
                lang: lang,
                onOpen: () => _openMonitoring(context, child),
                onUnlink: () => _confirmUnlink(context, child),
                onTransfer: () => _transferLearner(context, child),
              ),
            ),
        ];
    }
  }

  Future<void> _transferLearner(BuildContext context, LinkedChildModel child) =>
      CaregiverTransferFlow.create(context, child);
}

class _LinkedChildTile extends StatelessWidget {
  const _LinkedChildTile({
    required this.child,
    required this.theme,
    required this.lang,
    required this.onOpen,
    required this.onUnlink,
    required this.onTransfer,
  });

  final LinkedChildModel child;
  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final VoidCallback onOpen;
  final VoidCallback onUnlink;
  final VoidCallback onTransfer;

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
          crossAxisAlignment: CrossAxisAlignment.start,
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
            // Center the 24px dots button against the tile's 40px content.
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: CompactPopupMenu(
                vertical: true,
                iconColor: theme.textMain.withValues(alpha: 0.55),
                onSelected: (value) {
                  if (value == 'unlink') onUnlink();
                  if (value == 'transfer') onTransfer();
                },
                actions: [
                  CompactMenuAction(
                    value: 'transfer',
                    label: AppStrings.transferCaregiver(lang),
                    icon: Icons.swap_horiz_rounded,
                    color: theme.textMain,
                  ),
                  CompactMenuAction(
                    value: 'unlink',
                    label: AppStrings.unlinkChild(lang),
                    icon: Icons.link_off_rounded,
                    color: const Color(0xFFC62828),
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

class _AccessMessage extends StatelessWidget {
  const _AccessMessage({required this.theme, required this.title});

  final TapTalkThemeToken theme;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 15,
              height: 1.4,
              color: theme.textMain.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegacyLinksPanel extends StatefulWidget {
  const _LegacyLinksPanel({
    required this.theme,
    required this.lang,
    required this.learners,
  });

  final TapTalkThemeToken theme;
  final AppLanguage lang;
  final List<Map<String, dynamic>> learners;

  @override
  State<_LegacyLinksPanel> createState() => _LegacyLinksPanelState();
}

class _LegacyLinksPanelState extends State<_LegacyLinksPanel> {
  final _password = TextEditingController();
  final _code = TextEditingController();
  final _codes = <String>{};
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    final app = context.read<AppState>();
    String? error;
    try {
      await CaregiverSecurityService.instance.reauthenticate(
        password: _password.text,
      );
      error = await app.confirmLegacyCaregiverLinks(_codes.toList());
    } catch (_) {
      error = 'Account verification failed. Use this parent account.';
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final lang = widget.lang;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text(
          AppStrings.confirmLeftoverLinks(lang),
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: theme.textMain,
          ),
        ),
        const SizedBox(height: 8),
        for (final learner in widget.learners)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${(learner['learnerName'] as String?)?.trim().isNotEmpty == true ? learner['learnerName'] : 'Learner'}'
              '${learner['ambiguous'] == true ? ' — scan this learner QR first' : ''}',
              style: GoogleFonts.poppins(color: theme.textMain),
            ),
          ),
        if (widget.learners.any((learner) => learner['ambiguous'] == true)) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Conflicting learner code',
            ),
          ),
          TextButton(
            onPressed: () {
              final code = _code.text.trim().toUpperCase();
              if (!code.startsWith('TT-')) return;
              setState(() {
                _codes.add(code);
                _code.clear();
              });
            },
            child: Text(
              _codes.isEmpty
                  ? 'Save learner code'
                  : 'Saved: ${_codes.join(', ')}',
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: InputDecoration(
            labelText: lang == AppLanguage.filipino
                ? 'Password ng account'
                : 'Account password',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy ? null : _confirm,
          child: Text(AppStrings.confirmLeftoverLinks(lang)),
        ),
        if (_message != null) ...[
          const SizedBox(height: 12),
          Text(_message!, style: GoogleFonts.poppins(color: theme.textMain)),
        ],
      ],
    );
  }
}
