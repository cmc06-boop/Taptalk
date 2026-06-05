import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/l10n/app_strings.dart';
import '../data/models/sms_alert_result.dart';

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
    final normalized = <String>[];
    final invalid = <String>[];
    for (final raw in rawContacts.take(2)) {
      final phone = normalizePhoneNumber(raw);
      if (phone == null) {
        if (raw.trim().isNotEmpty) invalid.add(raw.trim());
      } else if (!normalized.contains(phone)) {
        normalized.add(phone);
      }
    }

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
      return _sendAndroidDirect(
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

  Future<SmsAlertResult> _sendAndroidDirect({
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

    var sent = 0;
    var failed = 0;
    String? lastError;
    final failedNumbers = <String>[];

    for (final to in numbers) {
      final address = toLocalSmsDialString(to);
      try {
        final ok = await _channel.invokeMethod<bool>('sendSms', {
          'to': address,
          'message': message,
        });
        if (ok == true) {
          sent++;
          debugPrint('Device SMS: sent to $address');
        } else {
          failed++;
          failedNumbers.add(address);
          lastError = AppStrings.smsSendFailed(language);
          debugPrint('Device SMS: failed to $address');
        }
      } on PlatformException catch (e, st) {
        failed++;
        failedNumbers.add(address);
        lastError = _mapPlatformError(language, e);
        debugPrint('Device SMS failed to $address: ${e.code} ${e.message}\n$st');
      } catch (e, st) {
        failed++;
        failedNumbers.add(address);
        lastError = AppStrings.smsSendFailed(language);
        debugPrint('Device SMS failed to $address: $e\n$st');
      }
    }

    if (sent > 0) {
      return SmsAlertResult(
        attempted: numbers.length,
        sent: sent,
        failed: failed,
        invalidContacts: invalid,
      );
    }

    // Some OEM phones (e.g. Transsion/Tecno) block silent SMS from third-party apps.
    // Fall back to the default Messages app with the alert pre-filled.
    return _openDefaultSmsApp(
      language: language,
      numbers: failedNumbers.isEmpty
          ? numbers.map(toLocalSmsDialString).toList()
          : failedNumbers,
      invalid: invalid,
      message: message,
      lastError: lastError,
    );
  }

  Future<SmsAlertResult> _openDefaultSmsApp({
    required AppLanguage language,
    required List<String> numbers,
    required List<String> invalid,
    required String message,
    String? lastError,
  }) async {
    final address = numbers.first;
    try {
      await _channel.invokeMethod<bool>('openSmsApp', {
        'to': address,
        'message': message,
      });
      debugPrint('Device SMS: opened Messages app for $address');
      return SmsAlertResult(
        attempted: numbers.length,
        sent: 1,
        failed: numbers.length > 1 ? numbers.length - 1 : 0,
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

  String _mapPlatformError(AppLanguage language, PlatformException error) {
    return switch (error.code) {
      'PERMISSION_DENIED' => AppStrings.smsPermissionDenied(language),
      'NO_SERVICE' || 'RADIO_OFF' => AppStrings.smsNoSignal(language),
      _ => AppStrings.smsSendFailed(language),
    };
  }

  Future<SmsAlertResult> _openSmsComposer({
    required AppLanguage language,
    required List<String> numbers,
    required List<String> invalid,
    required String message,
    String? lastError,
  }) async {
    final address = numbers.first;
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
      sent: launched ? 1 : 0,
      failed: launched ? numbers.length - 1 : numbers.length,
      invalidContacts: invalid,
      openedComposer: launched,
      errorMessage: launched ? null : (lastError ?? AppStrings.smsSendFailed(language)),
    );
  }
}
