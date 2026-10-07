import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/caregiver_security_gate.dart';
import 'package:flutter_test/flutter_test.dart';

class _MountProbe extends StatefulWidget {
  const _MountProbe(this.onMount);
  final VoidCallback onMount;
  @override
  State<_MountProbe> createState() => _MountProbeState();
}

class _MountProbeState extends State<_MountProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('Cached learner history'));
}

Widget _harness({
  required CaregiverSecurityCall call,
  VoidCallback? onMount,
  GlobalKey<NavigatorState>? navigatorKey,
  Future<void> Function()? onRevoked,
  Future<void> Function()? onMainBack,
  Future<void> Function(String, bool)? reauthenticate,
  Duration pollInterval = const Duration(minutes: 20),
}) => MaterialApp(
  navigatorKey: navigatorKey,
  builder: (context, child) => CaregiverSecurityGate(
    call: call,
    applyLinks: (_) async {},
    onTrusted: () async {},
    onRevoked: onRevoked ?? () async {},
    onLogout: () async {},
    onMainBack: onMainBack,
    reauthenticate: reauthenticate,
    recoveryProviders: const {'password'},
    pollInterval: pollInterval,
    child: child!,
  ),
  home: CaregiverSecurityRoute(child: _MountProbe(onMount ?? () {})),
);

Future<void> _tap(WidgetTester tester, String label) async {
  final button = find.text(label);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  tearDown(() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets(
    'cached learner content stays hidden until the server verifies trust',
    (tester) async {
      final response = Completer<Map<String, dynamic>>();
      var mounts = 0;
      await tester.pumpWidget(
        _harness(call: (_, _) => response.future, onMount: () => mounts++),
      );
      await tester.pump();
      expect(find.text('Cached learner history'), findsNothing);
      expect(
        find.text('Cached learner history', skipOffstage: false),
        findsOneWidget,
      );
      expect(mounts, 1);
      response.complete({'state': 'trusted', 'links': []});
      await tester.pumpAndSettle();
      expect(find.text('Cached learner history'), findsOneWidget);
      expect(mounts, 1);
    },
  );

  testWidgets(
    'resume hides cached routes and preserves the main navigator and route state',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      var mounts = 0;
      var checks = 0;
      final resumed = Completer<Map<String, dynamic>>();
      await tester.pumpWidget(
        _harness(
          navigatorKey: navigator,
          onMount: () => mounts++,
          call: (_, _) async => ++checks == 1
              ? {'state': 'trusted', 'links': []}
              : resumed.future,
        ),
      );
      await tester.pumpAndSettle();
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const CaregiverSecurityRoute(
              child: Scaffold(body: Text('Opened monitoring detail')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Opened monitoring detail'), findsOneWidget);
      final mountedNavigator = navigator.currentState;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('Opened monitoring detail'), findsNothing);
      expect(navigator.currentState, same(mountedNavigator));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Opened monitoring detail'), findsNothing);
      resumed.complete({'state': 'trusted', 'links': []});
      await tester.pumpAndSettle();
      expect(find.text('Opened monitoring detail'), findsOneWidget);
      expect(mounts, 1);
      expect(navigator.currentState, same(mountedNavigator));
    },
  );

  testWidgets(
    'a password-only new phone stays locked while approval is pending',
    (tester) async {
      var requests = 0;
      await tester.pumpWidget(
        _harness(
          call: (action, _) async {
            if (action == 'requestReplacement') {
              requests++;
              return {'requestId': 'new-phone-request'};
            }
            return {'state': 'verificationRequired'};
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(requests, 1);
      await _tap(tester, 'Check access again');
      expect(requests, 1);
      expect(find.text('new-phone-request'), findsOneWidget);
      expect(
        find.textContaining('Your old phone is still trusted.'),
        findsOneWidget,
      );
      expect(find.text('Cached learner history'), findsNothing);
      expect(
        find.text('Confirm replacement and revoke old phone'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'trusted phone automatically presents pending approval and locks on revocation',
    (tester) async {
      var approved = false;
      var revoked = 0;
      await tester.pumpWidget(
        _harness(
          call: (action, values) async {
            if (action == 'approveReplacement') {
              expect(values['requestId'], 'compare-on-both-phones');
              approved = true;
              return {'approved': true};
            }
            return approved
                ? {'state': 'verificationRequired'}
                : {
                    'state': 'trusted',
                    'links': [],
                    'requests': [
                      {'id': 'compare-on-both-phones'},
                    ],
                  };
          },
          onRevoked: () async => revoked++,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Approve new device and revoke this phone'),
        findsOneWidget,
      );
      expect(find.text('Cached learner history'), findsNothing);
      await _tap(tester, 'Approve new device and revoke this phone');
      expect(revoked, 1);
      expect(find.text('Cached learner history'), findsNothing);
    },
  );

  testWidgets(
    'new phone unlocks only when subsequent status confirms approval',
    (tester) async {
      var approved = false;
      await tester.pumpWidget(
        _harness(
          pollInterval: const Duration(seconds: 1),
          call: (_, _) async => approved
              ? {'state': 'trusted', 'links': []}
              : {'state': 'verificationRequired'},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cached learner history'), findsNothing);
      approved = true;
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Cached learner history'), findsOneWidget);
    },
  );

  testWidgets(
    'in-place account verification retains the request and requires explicit replacement confirmation',
    (tester) async {
      var replaced = false;
      final actions = <String>[];
      await tester.pumpWidget(
        _harness(
          call: (action, values) async {
            actions.add(action);
            if (action == 'requestReplacement') {
              return {'requestId': 'same-request'};
            }
            if ([
              'sendRecovery',
              'verifyRecovery',
              'confirmReplacement',
            ].contains(action)) {
              expect(values['requestId'], 'same-request');
              if (action == 'confirmReplacement') replaced = true;
              return {'ok': true};
            }
            return replaced
                ? {'state': 'trusted', 'links': []}
                : {'state': 'verificationRequired'};
          },
          reauthenticate: (password, google) async {
            expect(password, 'fresh-password');
            expect(google, false);
            actions.add('reauthenticate');
          },
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'Create replacement request');
      await _tap(tester, "I can't access my old device");
      await tester.enterText(
        find.widgetWithText(TextField, 'Account password'),
        'fresh-password',
      );
      await _tap(tester, 'Verify password and send email code');
      expect(
        actions.indexOf('reauthenticate'),
        lessThan(actions.indexOf('sendRecovery')),
      );
      expect(find.text('same-request'), findsOneWidget);
      expect(find.text('Cached learner history'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, '8-digit email code'),
        '12345678',
      );
      await _tap(tester, 'Verify recovery code');
      expect(
        find.text('Confirm replacement and revoke old phone'),
        findsOneWidget,
      );
      expect(find.text('Cached learner history'), findsNothing);
      await _tap(tester, 'Confirm replacement and revoke old phone');
      expect(find.text('Cached learner history'), findsOneWidget);
    },
  );

  testWidgets(
    'a status response from before backgrounding cannot unlock a resumed app',
    (tester) async {
      final stale = Completer<Map<String, dynamic>>();
      final fresh = Completer<Map<String, dynamic>>();
      var calls = 0;
      await tester.pumpWidget(
        _harness(call: (_, _) => ++calls == 1 ? stale.future : fresh.future),
      );
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      stale.complete({'state': 'trusted', 'links': []});
      await tester.pump();
      await tester.pump();
      expect(calls, 2);
      expect(find.text('Cached learner history'), findsNothing);
      fresh.complete({'state': 'verificationRequired'});
      await tester.pumpAndSettle();
      expect(
        find.text('Protected learner information is locked.'),
        findsOneWidget,
      );
      expect(find.text('Cached learner history'), findsNothing);
    },
  );

  testWidgets('system back on a covered main route does not pop it', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    var mainBackCalls = 0;
    await tester.pumpWidget(
      _harness(
        navigatorKey: navigator,
        call: (_, _) async => {'state': 'verificationRequired'},
        onMainBack: () async => mainBackCalls++,
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const CaregiverSecurityRoute(
            child: Scaffold(body: Text('Hidden detail')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(navigator.currentState!.canPop(), true);
    expect(mainBackCalls, 0);
  });
}
