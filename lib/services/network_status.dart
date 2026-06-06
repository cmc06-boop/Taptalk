import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Lightweight online/offline check for alert routing.
class NetworkStatus {
  static const _checkTimeout = Duration(seconds: 2);

  static DateTime? _cloudBlockedUntil;

  /// Call when a cloud request times out so we stop retrying for a while.
  static void markCloudUnreachable() {
    _cloudBlockedUntil = DateTime.now().add(const Duration(minutes: 2));
  }

  /// True after [markCloudUnreachable] until the cooldown expires.
  static bool get isCloudBlocked =>
      _cloudBlockedUntil != null &&
      DateTime.now().isBefore(_cloudBlockedUntil!);

  /// Device has no Wi‑Fi/mobile link. Does not treat a prior cloud timeout as offline.
  static Future<bool> isOffline() async {
    try {
      final results = await Connectivity()
          .checkConnectivity()
          .timeout(_checkTimeout);
      if (results.isEmpty) return true;
      return results.every((r) => r == ConnectivityResult.none);
    } on TimeoutException {
      debugPrint('Connectivity check timed out; assuming offline.');
      return true;
    } catch (e) {
      debugPrint('Connectivity check failed: $e');
      return true;
    }
  }
}
