import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/l10n/app_strings.dart';
import '../data/models/sms_alert_result.dart';
import '../data/repositories/app_repository.dart';

/// Sends SMS through the device's cellular plan (works without mobile data / Wi‑Fi).
class DeviceSmsService {
  static const _channel = MethodChannel('com.taptalk/direct_sms');

  String? normalizePhoneNumber(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^\d+]'), '').trim();
    if (cleaned.isEmpty) return null;
    if (cleaned.startsWith('+')) {
      if (RegExp(r'^\+\d{10,15}$').hasMatch(cleaned)) return cleaned;
      return null;
    }
    if (RegExp(r'^0\d{10}$').hasMatch(cleaned)) {
      return '+63${cleaned.substring(1)}';
    }
    if (RegExp(r'^63\d{10}$').hasMatch(cleaned)) {
      return '+$cleaned';
    }
    if (RegExp(r'^\d{10,15}$').hasMatch(cleaned)) {
      return '+$cleaned';
    }
    return null;
  }

  /// Android SmsManager expects local PH numbers (09…) for domestic SMS.
  String toLocalSmsDialString(String normalizedE164) {
    if (RegExp(r'^\+\d{10,15}$').hasMatch(normalizedE164)) {
      if (normalizedE164.startsWith('+63') && normalizedE164.length == 13) {
        return '0${normalizedE164.substring(3)}';
      }
      return normalizedE164.substring(1);
    }
    return normalizedE164;
  }

  String _multiRecipientAddress(List<String> localNumbers) {
    return localNumbers.join(';');
  }

  Future<bool> _ensureAndroidSmsPermissions() async {
    if (!Platform.isAndroid) return true;
    var status = await Permission.sms.status;
    if (!status.isGranted) {
      status = await Permission.sms.request();
    }
    return status.isGranted;
  }

  Future<SmsAlertResult> sendEmergencyAlert({
    required AppLanguage language,
    required List<String> rawContacts,
    required String message,
  }) async {
    final uniqueContacts = AppRepository.normalizeEmergencyContacts(rawContacts);
    final normalized = <String>[];
    final invalid = <String>[];
    for (final raw in uniqueContacts) {
      final phone = normalizePhoneNumber(raw);
      if (phone == null) {
        invalid.add(raw);
      } else if (!normalized.contains(phone)) {
        normalized.add(phone);
      }
    }

    debugPrint(
      'Device SMS: sending to ${normalized.length} recipient(s): '
      '${normalized.map(toLocalSmsDialString).join(", ")}',
    );

    if (normalized.isEmpty) {
      return SmsAlertResult(
        attempted: 0,
        sent: 0,
        failed: 0,
        invalidContacts: invalid,
        errorMessage: AppStrings.smsNoEmergencyContacts(language),
      );
    }

    if (Platform.isAndroid) {
      return _sendAndroidBatch(
        language: language,
        numbers: normalized,
        invalid: invalid,
        message: message,
      );
    }

    return _openSmsComposer(
      language: language,
      numbers: normalized,
      invalid: invalid,
      message: message,
    );
  }

  Future<SmsAlertResult> _sendAndroidBatch({
    required AppLanguage language,
    required List<String> numbers,
    required List<String> invalid,
    required String message,
  }) async {
    if (!await _ensureAndroidSmsPermissions()) {
      debugPrint('Device SMS: permission denied.');
      return SmsAlertResult(
        attempted: numbers.length,
        sent: 0,
        failed: numbers.length,
        invalidContacts: invalid,
        errorMessage: AppStrings.smsPermissionDenied(language),
      );
    }

    final addresses = numbers.map(toLocalSmsDialString).toList();

    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'sendSmsBatch',
        {
          'recipients': addresses,
          'message': message,
        },
      );

      final sent = (result?['sent'] as int?) ?? 0;
      final failed = (result?['failed'] as int?) ?? 0;
      final attempted = (result?['attempted'] as int?) ?? numbers.length;
      final failedNumbers = (result?['failedNumbers'] as List<Object?>?)
              ?.whereType<String>()
              .toList() ??
          <String>[];

      debugPrint(
        'Device SMS batch: sent=$sent failed=$failed attempted=$attempted',
      );

      if (sent == attempted && sent == numbers.length) {
        return SmsAlertResult(
          attempted: numbers.length,
          sent: sent,
          failed: 0,
          invalidContacts: invalid,
        );
      }

      final unsent =
          failedNumbers.isNotEmpty ? failedNumbers : addresses;

      final composer = await _openDefaultSmsApp(
        language: language,
        numbers: unsent,
        invalid: invalid,
        message: message,
        lastError: AppStrings.smsSendFailed(language),
        markComposerAsSent: sent == 0,
      );

      if (sent > 0) {
        return SmsAlertResult(
          attempted: numbers.length,
          sent: sent,
          failed: failed > 0 ? failed : numbers.length - sent,
          invalidContacts: invalid,
          openedComposer: composer.openedComposer,
          errorMessage: sent < numbers.length
              ? AppStrings.smsSendFailed(language)
              : null,
        );
      }

      return composer;
    } on PlatformException catch (e, st) {
      debugPrint('Device SMS batch failed: ${e.code} ${e.message}\n$st');
      if (e.code == 'PERMISSION_DENIED') {
        return SmsAlertResult(
          attempted: numbers.length,
          sent: 0,
          failed: numbers.length,
          invalidContacts: invalid,
          errorMessage: AppStrings.smsPermissionDenied(language),
        );
      }
      return _openDefaultSmsApp(
        language: language,
        numbers: addresses,
        invalid: invalid,
        message: message,
        lastError: AppStrings.smsSendFailed(language),
      );
    }
  }

  Future<SmsAlertResult> _openDefaultSmsApp({
    required AppLanguage language,
    required List<String> numbers,
    required List<String> invalid,
    required String message,
    String? lastError,
    bool markComposerAsSent = true,
  }) async {
    final address = _multiRecipientAddress(numbers);
    try {
      await _channel.invokeMethod<bool>('openSmsApp', {
        'to': address,
        'message': message,
      });
      debugPrint('Device SMS: opened Messages app for $address');
      return SmsAlertResult(
        attempted: numbers.length,
        sent: markComposerAsSent ? numbers.length : 0,
        failed: markComposerAsSent ? 0 : numbers.length,
        invalidContacts: invalid,
        openedComposer: true,
      );
    } on PlatformException catch (e, st) {
      debugPrint('openSmsApp failed for $address: ${e.code} ${e.message}\n$st');
      return _openSmsComposer(
        language: language,
        numbers: numbers,
        invalid: invalid,
        message: message,
        lastError: lastError,
      );
    }
  }

  Future<SmsAlertResult> _openSmsComposer({
    required AppLanguage language,
    required List<String> numbers,
    required List<String> invalid,
    required String message,
    String? lastError,
  }) async {
    final localNumbers = numbers.map(toLocalSmsDialString).toList();
    final address = _multiRecipientAddress(localNumbers);
    final uri = Uri(
      scheme: 'smsto',
      path: address,
      queryParameters: <String, String>{'body': message},
    );
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    return SmsAlertResult(
      attempted: numbers.length,
      sent: launched ? numbers.length : 0,
      failed: launched ? 0 : numbers.length,
      invalidContacts: invalid,
      openedComposer: launched,
      errorMessage:
          launched ? null : (lastError ?? AppStrings.smsSendFailed(language)),
    );
  }
}
