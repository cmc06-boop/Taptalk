import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../data/repositories/app_repository.dart';

abstract final class CodeQrUtils {
  static bool get isScanSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  static String? extractClassCode(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final direct = AppRepository.normalizeClassCode(trimmed);
    if (AppRepository.isValidClassCodeFormat(direct)) return direct;

    final upper = trimmed.toUpperCase();
    final patterns = [
      RegExp(r'CLS-[A-Z2-9]{8}'),
      RegExp(r'CLS-[0-9A-F]{8}'),
      RegExp(r'CLS[A-Z2-9]{8}'),
      RegExp(r'CLS[0-9A-F]{8}'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(upper);
      if (match == null) continue;
      final normalized = AppRepository.normalizeClassCode(match.group(0)!);
      if (AppRepository.isValidClassCodeFormat(normalized)) {
        return normalized;
      }
    }
    return null;
  }

  static String? extractTransferCode(String raw) {
    final upper = raw.trim().toUpperCase();
    final direct = RegExp(r'^TR-?([A-HJ-NP-Z2-9]{8})$').firstMatch(upper);
    if (direct != null) return 'TR-${direct.group(1)}';
    final shared = RegExp(
      r'(?:^|[^A-Z0-9])TR-([A-HJ-NP-Z2-9]{8})(?![A-Z0-9])',
    ).firstMatch(upper);
    return shared == null ? null : 'TR-${shared.group(1)}';
  }

  static String? extractProfileCode(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final direct = AppRepository.normalizeProfileCode(trimmed);
    if (AppRepository.isValidProfileCodeFormat(direct)) return direct;

    final upper = trimmed.toUpperCase();
    final patterns = [
      RegExp(r'TT-[A-Z2-9]{8}'),
      RegExp(r'TT-[0-9A-F]{10}'),
      RegExp(r'TT[A-Z2-9]{8}'),
      RegExp(r'TT[0-9A-F]{10}'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(upper);
      if (match == null) continue;
      final normalized = AppRepository.normalizeProfileCode(match.group(0)!);
      if (AppRepository.isValidProfileCodeFormat(normalized)) {
        return normalized;
      }
    }
    return null;
  }
}
