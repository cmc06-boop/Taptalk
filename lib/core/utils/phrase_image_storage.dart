import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Copies gallery/temp image files into app storage so paths stay valid.
Future<String?> persistPhraseImageIfNeeded(String? sourcePath) async {
  if (sourcePath == null || sourcePath.isEmpty) return null;

  final lower = sourcePath.toLowerCase();
  if (lower.startsWith('assets/')) return sourcePath;

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
  final safeExt = ext.isEmpty || ext.length > 8 ? '.jpg' : ext;
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
  if (lower.startsWith('assets/')) return trimmed;
  if (isRemotePhraseImagePath(trimmed)) {
    return cachedPhraseImagePathSync(trimmed);
  }
  if (kIsWeb) return trimmed;
  final file = File(trimmed);
  return file.existsSync() ? trimmed : null;
}

/// Sync lookup — returns a local cache file path when the remote image was saved before.
String? cachedPhraseImagePathSync(String? imagePath) {
  if (imagePath == null || imagePath.trim().isEmpty || kIsWeb) return null;
  if (_documentsPath == null) return null;
  if (!isRemotePhraseImagePath(imagePath)) return null;
  final file = _cacheFileForSource(imagePath.trim());
  return file.existsSync() ? file.path : null;
}

/// Resolves phrase images to a device path. Downloads http(s)/data URLs once when online.
Future<String?> cachePhraseImageLocally(String? imagePath) async {
  if (imagePath == null || imagePath.trim().isEmpty) return null;
  final trimmed = imagePath.trim();
  final lower = trimmed.toLowerCase();

  if (lower.startsWith('assets/')) return trimmed;
  if (kIsWeb) return trimmed;

  await warmPhraseImageCacheDirectory();

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

/// Keeps cloud URLs in the database when offline, but prefers local cache when available.
Future<String?> resolveStoredPhraseImagePath(String? imagePath) async {
  if (imagePath == null || imagePath.trim().isEmpty) return null;
  final cached = await cachePhraseImageLocally(imagePath);
  return cached ?? imagePath.trim();
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

    await cacheFile.parent.create(recursive: true);
    await cacheFile.writeAsBytes(bytes, flush: true);
    return cacheFile.path;
  } catch (e, st) {
    debugPrint('Phrase image download cache failed: $e\n$st');
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

String _extensionForSource(String source) {
  final lower = source.toLowerCase();
  if (lower.startsWith('data:')) {
    final mime = RegExp(r'^data:([^;]+);').firstMatch(lower)?.group(1) ?? '';
    return switch (mime) {
      'image/png' => '.png',
      'image/webp' => '.webp',
      'image/gif' => '.gif',
      _ => '.jpg',
    };
  }

  final uri = Uri.tryParse(source);
  final path = uri?.path.toLowerCase() ?? lower;
  if (path.endsWith('.png')) return '.png';
  if (path.endsWith('.webp')) return '.webp';
  if (path.endsWith('.gif')) return '.gif';
  return '.jpg';
}
