import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models/sms_alert_result.dart';

/// Sends SMS through the device's cellular plan (works without mobile data / Wi‑Fi).
class DeviceSmsService {
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

  Future<bool> _ensureSmsPermission() async {
    if (!Platform.isAndroid) return true;
    var status = await Permission.sms.status;
    if (status.isGranted) return true;
    status = await Permission.sms.request();
    return status.isGranted;
  }

  Future<SmsAlertResult> sendEmergencyAlert({
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
        errorMessage: 'No valid emergency contact numbers.',
      );
    }

    if (Platform.isAndroid) {
      return _sendAndroidDirect(
        numbers: normalized,
        invalid: invalid,
        message: message,
      );
    }

    return _openSmsComposer(
      numbers: normalized,
      invalid: invalid,
      message: message,
    );
  }

  Future<SmsAlertResult> _sendAndroidDirect({
    required List<String> numbers,
    required List<String> invalid,
    required String message,
  }) async {
    if (!await _ensureSmsPermission()) {
      return _openSmsComposer(
        numbers: numbers,
        invalid: invalid,
        message: message,
      );
    }

    final telephony = Telephony.instance;
    final granted = await telephony.requestPhoneAndSmsPermissions;
    if (granted != true) {
      return _openSmsComposer(
        numbers: numbers,
        invalid: invalid,
        message: message,
      );
    }

    var sent = 0;
    var failed = 0;
    for (final to in numbers) {
      try {
        await telephony.sendSms(to: to, message: message);
        sent++;
      } catch (e, st) {
        debugPrint('Device SMS failed to $to: $e\n$st');
        failed++;
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

    return _openSmsComposer(
      numbers: numbers,
      invalid: invalid,
      message: message,
    );
  }

  Future<SmsAlertResult> _openSmsComposer({
    required List<String> numbers,
    required List<String> invalid,
    required String message,
  }) async {
    final target = numbers.first;
    final uri = Uri(
      scheme: 'sms',
      path: target,
      queryParameters: <String, String>{'body': message},
    );
    final launched = await launchUrl(uri);
    return SmsAlertResult(
      attempted: numbers.length,
      sent: launched ? 1 : 0,
      failed: launched ? numbers.length - 1 : numbers.length,
      invalidContacts: invalid,
      errorMessage: launched
          ? null
          : 'Could not open the SMS app. Check emergency contacts.',
    );
  }
}
