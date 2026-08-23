import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'phrase_image_storage.dart';

String? _docs;

Future<void> warmPhraseVideoPosterDirectory() async {
  if (kIsWeb) return;
  if (_docs != null) return;
  final docs = await getApplicationDocumentsDirectory();
  _docs = docs.path;
  final dir = Directory(p.join(_docs!, 'phrase_images', 'posters'));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
}

File _posterFile(String source) {
  final digest = sha256.convert(utf8.encode(source)).toString();
  return File(
    p.join(
      _docs!,
      'phrase_images',
      'posters',
      '${digest.substring(0, 24)}_hq.png',
    ),
  );
}

/// Sync lookup for an already-captured first frame.
String? cachedPhraseVideoPosterPathSync(String? mediaPath) {
  if (mediaPath == null || mediaPath.trim().isEmpty || kIsWeb) return null;
  if (_docs == null) return null;
  if (!isPhraseVideoPath(mediaPath)) return null;
  final file = _posterFile(mediaPath.trim());
  return file.existsSync() && file.lengthSync() > 0 ? file.path : null;
}

/// Persists a captured first-frame PNG for [mediaPath].
Future<String?> savePhraseVideoPosterBytes(
  String mediaPath,
  Uint8List bytes,
) async {
  if (kIsWeb || bytes.isEmpty || !isPhraseVideoPath(mediaPath)) return null;
  await warmPhraseVideoPosterDirectory();
  if (_docs == null) return null;
  final dest = _posterFile(mediaPath.trim());
  try {
    await dest.parent.create(recursive: true);
    await dest.writeAsBytes(bytes, flush: true);
    return dest.path;
  } catch (e, st) {
    debugPrint('Phrase video poster save failed ($mediaPath): $e\n$st');
    return null;
  }
}
