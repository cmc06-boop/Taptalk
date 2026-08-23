import 'dart:async';

/// Lets Speak wait until the on-screen 720p player actually starts.
class PhraseVideoSpeakSync {
  static Completer<void>? _ready;

  static void arm() {
    if (_ready != null && !_ready!.isCompleted) {
      _ready!.complete();
    }
    _ready = Completer<void>();
  }

  static void signalReady() {
    final c = _ready;
    if (c != null && !c.isCompleted) c.complete();
  }

  static Future<void> wait({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final c = _ready;
    if (c == null || c.isCompleted) return;
    try {
      await c.future.timeout(timeout);
    } on TimeoutException {
      // Speak anyway if the decoder is stuck.
    }
  }

  static void disarm() {
    final c = _ready;
    if (c != null && !c.isCompleted) c.complete();
    _ready = null;
  }
}
