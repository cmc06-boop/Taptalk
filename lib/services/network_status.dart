import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Lightweight online/offline check for alert routing.
class NetworkStatus {
  static const _checkTimeout = Duration(seconds: 2);

  static Future<bool> isOffline() async {
    try {
      final results = await Connectivity()
          .checkConnectivity()
          .timeout(_checkTimeout);
      if (results.isEmpty) return true;
      return results.every((r) => r == ConnectivityResult.none);
    } on TimeoutException {
      debugPrint('Connectivity check timed out; assuming online.');
      return false;
    } catch (e) {
      debugPrint('Connectivity check failed: $e');
      return false;
    }
  }
}
