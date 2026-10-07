import '../core/l10n/app_strings.dart';
import '../core/utils/negative_phrases.dart';
import '../data/repositories/app_repository.dart';
import 'device_sms_service.dart';

/// One automatic submission per teacher/device, learner, phrase, day and number.
/// Failed numbers can retry after a cooldown; successful numbers are not resent.
class NegativeUsageSmsService {
  NegativeUsageSmsService({
    required this.repository,
    required this.sms,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final AppRepository repository;
  final DeviceSmsService sms;
  final DateTime Function() now;

  Future<String> send({
    required int teacherUserId,
    required int learnerUserId,
    required String phraseKey,
    required DateTime dayStart,
    required AppLanguage language,
    required List<String> contacts,
    required String message,
    required bool Function() canSend,
  }) async {
    final key = NegativePhrases.normalizeText(phraseKey);
    final numbers = contacts
        .map(sms.normalizePhoneNumber)
        .whereType<String>()
        .toSet();
    if (numbers.isEmpty) return AppStrings.smsNoEmergencyContacts(language);
    for (final number in numbers) {
      if (!canSend()) break;
      final claimed = await repository.claimWarningSms(
        teacherUserId: teacherUserId,
        learnerUserId: learnerUserId,
        phraseKey: key,
        dayStart: dayStart,
        phoneNumber: number,
        now: now(),
      );
      if (!claimed) continue;
      var submitted = false;
      String? error;
      try {
        if (canSend()) {
          final result = await sms.sendAutomaticAlert(
            language: language,
            phoneNumber: number,
            message: message,
          );
          submitted =
              result.sent == 1 &&
              !result.openedComposer &&
              result.errorMessage == null;
          error = result.errorMessage;
        } else {
          error = AppStrings.notSignedIn(language);
        }
      } catch (_) {
        error = AppStrings.smsSendFailed(language);
      }
      await repository.finishWarningSms(
        teacherUserId: teacherUserId,
        learnerUserId: learnerUserId,
        phraseKey: key,
        dayStart: dayStart,
        phoneNumber: number,
        submitted: submitted,
        error: error,
      );
    }
    final rows = await repository.getWarningSmsDeliveries(
      teacherUserId: teacherUserId,
      learnerUserId: learnerUserId,
      phraseKey: key,
      dayStart: dayStart,
    );
    final submitted = rows
        .where(
          (r) =>
              numbers.contains(r['phone_number']) && r['status'] == 'submitted',
        )
        .length;
    final error = rows
        .where(
          (r) => numbers.contains(r['phone_number']) && r['status'] == 'failed',
        )
        .map((r) => r['last_error'])
        .whereType<String>()
        .firstOrNull;
    return AppStrings.automaticSmsStatus(
      language,
      submitted,
      numbers.length,
      error,
    );
  }
}
