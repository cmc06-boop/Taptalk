import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Copies gallery/temp image files into app storage so paths stay valid.
Future<String?> persistPhraseImageIfNeeded(String? sourcePath) async {
  if (sourcePath == null || sourcePath.isEmpty) return null;

  final lower = sourcePath.toLowerCase();
  if (lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('assets/')) {
    return sourcePath;
  }

  if (kIsWeb) return sourcePath;

  final source = File(sourcePath);
  if (!await source.exists()) return null;

  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'phrase_images'));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  final ext = p.extension(sourcePath);
  final safeExt = ext.isEmpty || ext.length > 8 ? '.jpg' : ext;
  final dest = File(p.join(dir.path, '${const Uuid().v4()}$safeExt'));
  await source.copy(dest.path);
  return dest.path;
}
