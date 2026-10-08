import 'package:flutter_application_1/services/caregiver_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a trusted phone syncs monitoring and does not ask the user again', () {
    final plan = CaregiverAccessPlan.fromStatus('trusted');
    expect(plan.access, CaregiverAccess.trusted);
    expect(plan.syncProtected, isTrue);
  });

  test('an account without a trusted phone yet does not sync monitoring', () {
    final plan = CaregiverAccessPlan.fromStatus('setup');
    expect(plan.access, CaregiverAccess.setup);
    expect(plan.syncProtected, isFalse);
  });

  test('another phone must verify and never syncs monitoring', () {
    final plan = CaregiverAccessPlan.fromStatus('verificationRequired');
    expect(plan.access, CaregiverAccess.verifyDevice);
    expect(plan.syncProtected, isFalse);
  });

  test('an unreachable server does not pretend the phone was rejected', () {
    expect(
      CaregiverAccessPlan.fromStatus('offline').access,
      CaregiverAccess.unavailable,
    );
  });
}
