import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../l10n/app_strings.dart';

/// Speaks [text] and shows a snackbar if device TTS is unavailable offline.
Future<void> speakWithFeedback(
  BuildContext context,
  String text, {
  bool record = false,
  String? categoryKey,
}) async {
  final app = context.read<AppState>();
  if (text.trim().isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.enterText(app.language))),
      );
    }
    return;
  }
  final ok = await app.speakText(
    text,
    record: record,
    categoryKey: categoryKey,
  );
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.ttsNotAvailable(app.language))),
    );
  }
}
