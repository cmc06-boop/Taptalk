/// User-facing speech rate (0.25x = very slow, 1.0x = normal, 2.0x = fast).
abstract final class TtsSpeedOptions {
  static const double min = 0.25;
  static const double max = 2.0;
  static const double defaultSpeed = 0.25;

  /// Discrete speeds shown on the slider and scale labels (matches Settings UI).
  static const List<double> scaleMarks = [0.25, 0.5, 1.0, 1.5, 2.0];

  static int get sliderDivisions => scaleMarks.length - 1;

  /// Snaps [speed] to the nearest [scaleMarks] value so the thumb aligns with labels.
  static double snap(double speed) {
    if (scaleMarks.isEmpty) return defaultSpeed;
    var nearest = scaleMarks.first;
    var smallestDiff = (speed - nearest).abs();
    for (final mark in scaleMarks) {
      final diff = (speed - mark).abs();
      if (diff < smallestDiff) {
        smallestDiff = diff;
        nearest = mark;
      }
    }
    return nearest;
  }

  /// Keeps [speed] within range, then snaps to a scale mark.
  static double clamp(double speed) => snap(speed.clamp(min, max).toDouble());

  static int indexOf(double speed) {
    final snapped = snap(speed);
    final index = scaleMarks.indexOf(snapped);
    return index >= 0 ? index : scaleMarks.indexOf(defaultSpeed);
  }

  static double valueAtIndex(int index) {
    if (index <= 0) return scaleMarks.first;
    if (index >= scaleMarks.length) return scaleMarks.last;
    return scaleMarks[index];
  }

  static String label(double speed) {
    final value = snap(speed);
    if (value == 0.25) return '0.25x';
    if (value == 0.5) return '0.50x';
    if (value == 1.0) return '1.00x';
    if (value == 1.5) return '1.50x';
    if (value == 2.0) return '2.00x';
    return '${value.toStringAsFixed(2)}x';
  }

  static String shortLabel(double speed) {
    final value = snap(speed);
    if (value == 0.25) return '0.25x';
    if (value == 0.5) return '0.5x';
    if (value == 1.0) return '1x';
    if (value == 1.5) return '1.5x';
    if (value == 2.0) return '2x';
    return '${value.toStringAsFixed(2)}x';
  }
}
