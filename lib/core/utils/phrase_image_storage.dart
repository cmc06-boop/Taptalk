import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

bool isPhraseVideoPath(String? path) {
  if (path == null || path.trim().isEmpty) return false;
  final lower = path.trim().toLowerCase();
  final pathOnly = Uri.tryParse(lower)?.path ?? lower;
  return pathOnly.endsWith('.mp4') ||
      pathOnly.endsWith('.webm') ||
      pathOnly.endsWith('.mov') ||
      pathOnly.endsWith('.m4v') ||
      lower.contains('video/mp4') ||
      lower.contains('video/webm');
}

/// Copies gallery/temp media into app storage so paths stay valid after restart.
Future<String?> persistPhraseImageIfNeeded(String? sourcePath) async {
  if (sourcePath == null || sourcePath.isEmpty) return null;

  final lower = sourcePath.toLowerCase();
  if (lower.startsWith('assets/')) {
    if (isPhraseVideoPath(sourcePath)) {
      return ensureLocalPhraseMediaPath(sourcePath);
    }
    return sourcePath;
  }

  if (lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('data:')) {
    final cached = await cachePhraseImageLocally(sourcePath);
    return cached ?? sourcePath;
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
  final safeExt = ext.isEmpty || ext.length > 8
      ? (isPhraseVideoPath(sourcePath) ? '.mp4' : '.jpg')
      : ext;
  final dest = File(p.join(dir.path, '${const Uuid().v4()}$safeExt'));
  await source.copy(dest.path);
  return dest.path;
}

bool isRemotePhraseImagePath(String? imagePath) {
  if (imagePath == null || imagePath.trim().isEmpty) return false;
  final lower = imagePath.trim().toLowerCase();
  return lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('data:');
}

/// Returns a path that can be shown immediately without downloading.
String? existingPhraseImagePath(String? imagePath) {
  if (imagePath == null || imagePath.trim().isEmpty) return null;
  final trimmed = imagePath.trim();
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('assets/')) {
    if (isPhraseVideoPath(trimmed)) {
      return cachedPhraseImagePathSync(trimmed) ?? trimmed;
    }
    return trimmed;
  }
  if (isRemotePhraseImagePath(trimmed)) {
    return cachedPhraseImagePathSync(trimmed);
  }
  if (kIsWeb) return trimmed;
  final file = File(trimmed);
  return file.existsSync() ? trimmed : null;
}

/// Sync lookup — local cache file path when the source was saved before.
String? cachedPhraseImagePathSync(String? imagePath) {
  if (imagePath == null || imagePath.trim().isEmpty || kIsWeb) return null;
  if (_documentsPath == null) return null;
  final trimmed = imagePath.trim();
  final lower = trimmed.toLowerCase();
  if (!isRemotePhraseImagePath(trimmed) &&
      !(lower.startsWith('assets/') && isPhraseVideoPath(trimmed))) {
    return null;
  }
  final file = _cacheFileForSource(trimmed);
  return file.existsSync() ? file.path : null;
}

/// Resolves phrase media to a device path. Downloads http(s)/data URLs once
/// when online, and materializes asset videos/images into app documents.
Future<String?> cachePhraseImageLocally(String? imagePath) async {
  if (imagePath == null || imagePath.trim().isEmpty) return null;
  final trimmed = imagePath.trim();
  final lower = trimmed.toLowerCase();

  if (kIsWeb) return trimmed;

  await warmPhraseImageCacheDirectory();

  if (lower.startsWith('assets/')) {
    if (isPhraseVideoPath(trimmed)) {
      return _materializeAssetToCache(trimmed);
    }
    return trimmed;
  }

  if (!isRemotePhraseImagePath(trimmed)) {
    final file = File(trimmed);
    return file.existsSync() ? trimmed : null;
  }

  final cacheFile = _cacheFileForSource(trimmed);
  if (await cacheFile.exists() && await cacheFile.length() > 0) {
    return cacheFile.path;
  }

  if (lower.startsWith('data:')) {
    return _writeDataUrlToCache(trimmed, cacheFile);
  }

  return _downloadUrlToCache(trimmed, cacheFile);
}

/// Ensures media is on-device for offline playback (assets, remote, or files).
Future<String?> ensureLocalPhraseMediaPath(String? imagePath) async {
  if (imagePath == null || imagePath.trim().isEmpty) return null;
  final cached = await cachePhraseImageLocally(imagePath);
  return cached ?? imagePath.trim();
}

/// Keeps cloud URLs in the database when offline, but prefers local cache when available.
Future<String?> resolveStoredPhraseImagePath(String? imagePath) async {
  return ensureLocalPhraseMediaPath(imagePath);
}

Future<String?> _materializeAssetToCache(String assetPath) async {
  final cacheFile = _cacheFileForSource(assetPath);
  if (await cacheFile.exists() && await cacheFile.length() > 0) {
    return cacheFile.path;
  }

  try {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    if (bytes.isEmpty) return assetPath;
    await cacheFile.parent.create(recursive: true);
    await cacheFile.writeAsBytes(bytes, flush: true);
    return cacheFile.path;
  } catch (e, st) {
    debugPrint('Phrase asset materialize failed: $e\n$st');
    return assetPath;
  }
}

Future<String?> _writeDataUrlToCache(String dataUrl, File cacheFile) async {
  final match = RegExp(r'^data:([^;]+);base64,(.+)$').firstMatch(dataUrl);
  if (match == null) return null;

  try {
    final bytes = base64Decode(match.group(2)!);
    if (bytes.isEmpty) return null;
    await cacheFile.parent.create(recursive: true);
    await cacheFile.writeAsBytes(bytes, flush: true);
    return cacheFile.path;
  } catch (e, st) {
    debugPrint('Phrase image data-url cache failed: $e\n$st');
    return null;
  }
}

Future<String?> _downloadUrlToCache(String url, File cacheFile) async {
  HttpClient? client;
  try {
    client = HttpClient();
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set('User-Agent', 'TapTalk/1.0');
    final response = await request.close();
    if (response.statusCode != 200) return null;

    final bytes = await consolidateHttpClientResponseBytes(response);
    if (bytes.isEmpty) return null;

    var target = cacheFile;
    final mime = response.headers.contentType?.mimeType.toLowerCase();
    final mimeExt = _extensionForMime(mime);
    if (mimeExt != null && p.extension(target.path) != mimeExt) {
      target = File(
        p.join(
          target.parent.path,
          '${p.basenameWithoutExtension(target.path)}$mimeExt',
        ),
      );
    }

    await target.parent.create(recursive: true);
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  } catch (e, st) {
    debugPrint('Phrase media download cache failed: $e\n$st');
    return null;
  } finally {
    client?.close(force: true);
  }
}

File _cacheFileForSource(String source) {
  final digest = sha256.convert(utf8.encode(source)).toString();
  final ext = _extensionForSource(source);
  final name = '${digest.substring(0, 24)}$ext';
  return File(p.join(_cacheDirectoryPathSync(), name));
}

String _cacheDirectoryPathSync() {
  return p.join(_documentsPath!, 'phrase_images', 'cache');
}

String? _documentsPath;

Future<void> warmPhraseImageCacheDirectory() async {
  if (kIsWeb) return;
  final docs = await getApplicationDocumentsDirectory();
  _documentsPath = docs.path;
  final dir = Directory(p.join(docs.path, 'phrase_images', 'cache'));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
}

String? _extensionForMime(String? mime) {
  if (mime == null || mime.isEmpty) return null;
  return switch (mime) {
    'video/mp4' || 'video/mpeg' => '.mp4',
    'video/webm' => '.webm',
    'video/quicktime' => '.mov',
    'image/png' => '.png',
    'image/webp' => '.webp',
    'image/gif' => '.gif',
    'image/jpeg' || 'image/jpg' => '.jpg',
    _ => null,
  };
}

String _extensionForSource(String source) {
  final lower = source.toLowerCase();
  if (lower.startsWith('data:')) {
    final mime = RegExp(r'^data:([^;]+);').firstMatch(lower)?.group(1) ?? '';
    return _extensionForMime(mime) ??
        (mime.startsWith('video/') ? '.mp4' : '.jpg');
  }

  final uri = Uri.tryParse(source);
  final path = uri?.path.toLowerCase() ?? lower;
  if (path.endsWith('.mp4')) return '.mp4';
  if (path.endsWith('.webm')) return '.webm';
  if (path.endsWith('.mov')) return '.mov';
  if (path.endsWith('.m4v')) return '.m4v';
  if (path.endsWith('.png')) return '.png';
  if (path.endsWith('.webp')) return '.webp';
  if (path.endsWith('.gif')) return '.gif';
  if (path.endsWith('.jpeg') || path.endsWith('.jpg')) return '.jpg';
  if (isPhraseVideoPath(source)) return '.mp4';
  return '.jpg';
}
