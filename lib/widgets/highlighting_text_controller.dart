import 'package:flutter/material.dart';

TextSpan buildHighlightedTextSpan({
  required String text,
  required int start,
  required int end,
  required Color accent,
  TextStyle? style,
}) {
  final clampedStart = start.clamp(0, text.length);
  final clampedEnd = end.clamp(0, text.length);
  if (clampedStart >= clampedEnd || text.isEmpty) {
    return TextSpan(style: style, text: text);
  }

  return TextSpan(
    style: style,
    children: [
      TextSpan(text: text.substring(0, clampedStart)),
      TextSpan(
        text: text.substring(clampedStart, clampedEnd),
        style: TextStyle(
          color: Colors.white,
          backgroundColor: accent.withValues(alpha: 0.95),
          fontWeight: FontWeight.w700,
        ),
      ),
      TextSpan(text: text.substring(clampedEnd)),
    ],
  );
}

/// Text controller that highlights a word range while TTS read-along is active.
class HighlightingTextController extends TextEditingController {
  int _highlightStart = -1;
  int _highlightEnd = -1;
  Color _accent = const Color(0xFF5BB88A);

  void updateHighlight({
    required int start,
    required int end,
    required Color accent,
  }) {
    if (_highlightStart == start &&
        _highlightEnd == end &&
        _accent == accent) {
      return;
    }
    _highlightStart = start;
    _highlightEnd = end;
    _accent = accent;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    return buildHighlightedTextSpan(
      text: text,
      start: _highlightStart,
      end: _highlightEnd,
      accent: _accent,
      style: style,
    );
  }
}
