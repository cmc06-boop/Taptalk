/// What the parent app should do after a caregiver security status check.
///
/// Only one phone per parent account is trusted. Any other phone gets
/// [CaregiverAccess.verifyDevice] and must pass the email-link check before
/// the parent account can be used there.
enum CaregiverAccess {
  unknown,
  trusted,
  setup,
  verifyDevice,
  legacy,
  unavailable,
}

class CaregiverAccessPlan {
  const CaregiverAccessPlan({
    required this.access,
    required this.syncProtected,
  });

  final CaregiverAccess access;
  final bool syncProtected;

  static CaregiverAccessPlan fromStatus(String? state) {
    switch (state) {
      case 'trusted':
        return const CaregiverAccessPlan(
          access: CaregiverAccess.trusted,
          syncProtected: true,
        );
      case 'setup':
        return const CaregiverAccessPlan(
          access: CaregiverAccess.setup,
          syncProtected: false,
        );
      case 'legacyConfirmation':
        return const CaregiverAccessPlan(
          access: CaregiverAccess.legacy,
          syncProtected: false,
        );
      case 'verificationRequired':
        return const CaregiverAccessPlan(
          access: CaregiverAccess.verifyDevice,
          syncProtected: false,
        );
      default:
        return const CaregiverAccessPlan(
          access: CaregiverAccess.unavailable,
          syncProtected: false,
        );
    }
  }
}
