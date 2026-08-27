import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../services/firebase_service.dart';

const String phraseMediaCollectionName = 'phrase_media_cloud';
const String phraseMediaScheme = 'taptalk-fs-media://';

bool isFirestorePhraseMediaPath(String? imagePath) {
  final trimmed = imagePath?.trim() ?? '';
  return trimmed.toLowerCase().startsWith(phraseMediaScheme);
}

String? firestorePhraseMediaDocId(String imagePath) {
  if (!isFirestorePhraseMediaPath(imagePath)) return null;
  final rest = imagePath.trim().substring(phraseMediaScheme.length);
  if (rest.isEmpty) return null;
  final withoutExt = p.basenameWithoutExtension(rest);
  return withoutExt.isEmpty ? rest : withoutExt;
}

bool isPhraseVideoPath(String? path) {
  if (path == null || path.trim().isEmpty) return false;
  final lower = path.trim().toLowerCase();
  final uri = Uri.tryParse(lower);
  final candidates = <String>[
    lower,
    uri?.path ?? '',
    uri?.host ?? '',
  ];
  for (final value in candidates) {
    if (value.endsWith('.mp4') ||
        value.endsWith('.webm') ||
        value.endsWith('.mov') ||
        value.endsWith('.m4v')) {
      return true;
    }
  }
  return lower.contains('video/mp4') || lower.contains('video/webm');
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
      lower.startsWith('data:') ||
      isFirestorePhraseMediaPath(sourcePath)) {
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

  final looksVideo =
      isPhraseVideoPath(sourcePath) || await _fileLooksLikeMp4(source);
  final ext = p.extension(sourcePath);
  final safeExt = ext.isEmpty || ext.length > 8
      ? (looksVideo ? '.mp4' : '.jpg')
      : (looksVideo && !_isVideoExt(ext) ? '.mp4' : ext);
  final dest = File(p.join(dir.path, '${const Uuid().v4()}$safeExt'));
  await source.copy(dest.path);
  return dest.path;
}

bool _isVideoExt(String ext) {
  final lower = ext.toLowerCase();
  return lower == '.mp4' ||
      lower == '.webm' ||
      lower == '.mov' ||
      lower == '.m4v';
}

Future<bool> _fileLooksLikeMp4(File file) async {
  RandomAccessFile? raf;
  try {
    raf = await file.open();
    final header = await raf.read(12);
    if (header.length < 8) return false;
    // ISO BMFF: bytes 4..7 spell "ftyp"
    return header[4] == 0x66 &&
        header[5] == 0x74 &&
        header[6] == 0x79 &&
        header[7] == 0x70;
  } catch (_) {
    return false;
  } finally {
    await raf?.close();
  }
}

/// Copies an already-local file into the cache slot for [remoteRef] so the UI
/// can keep showing the video instantly after the DB switches to a cloud path.
Future<String?> seedPhraseMediaCacheFromLocal({
  required String remoteRef,
  required String localPath,
}) async {
  if (kIsWeb) return null;
  final ref = remoteRef.trim();
  final local = localPath.trim();
  if (ref.isEmpty || local.isEmpty) return null;
  if (!isRemotePhraseImagePath(ref) && !isFirestorePhraseMediaPath(ref)) {
    return null;
  }
  final source = File(local);
  if (!await source.exists() || await source.length() <= 0) return null;

  await warmPhraseImageCacheDirectory();
  var dest = _cacheFileForSource(ref);
  final preferredExt = p.extension(local).isNotEmpty
      ? p.extension(local)
      : _extensionForSource(ref);
  if (preferredExt.isNotEmpty &&
      p.extension(dest.path).toLowerCase() != preferredExt.toLowerCase()) {
    dest = File(
      p.join(
        dest.parent.path,
        '${p.basenameWithoutExtension(dest.path)}$preferredExt',
      ),
    );
  }
  try {
    if (await dest.exists() && await dest.length() > 0) {
      return dest.path;
    }
    await dest.parent.create(recursive: true);
    await source.copy(dest.path);
    return dest.path;
  } catch (e, st) {
    debugPrint('Seed phrase media cache failed: $e\n$st');
    return null;
  }
}

bool isRemotePhraseImagePath(String? imagePath) {
  if (imagePath == null || imagePath.trim().isEmpty) return false;
  final lower = imagePath.trim().toLowerCase();
  return lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('data:') ||
      isFirestorePhraseMediaPath(imagePath);
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

  if (isFirestorePhraseMediaPath(trimmed)) {
    return _downloadFirestoreMediaToCache(trimmed, cacheFile);
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

Future<String?> _downloadFirestoreMediaToCache(String ref, File cacheFile) async {
  final docId = firestorePhraseMediaDocId(ref);
  if (docId == null || docId.isEmpty) return null;

  await FirebaseService.instance.initialize();
  if (!FirebaseService.instance.isAvailable) return null;

  try {
    final firestore = FirebaseFirestore.instance;
    final meta =
        await firestore.collection(phraseMediaCollectionName).doc(docId).get();
    if (!meta.exists) return null;
    final data = meta.data() ?? {};
    final chunkCount = data['chunkCount'] as int? ?? 0;
    if (chunkCount <= 0) return null;
    final ext = (data['ext'] as String?)?.trim();
    var target = cacheFile;
    if (ext != null &&
        ext.isNotEmpty &&
        p.extension(target.path).toLowerCase() != ext.toLowerCase()) {
      target = File(
        p.join(
          target.parent.path,
          '${p.basenameWithoutExtension(target.path)}$ext',
        ),
      );
    }
    if (await target.exists() && await target.length() > 0) {
      return target.path;
    }

    final builder = BytesBuilder(copy: false);
    for (var i = 0; i < chunkCount; i++) {
      final chunkDoc = await firestore
          .collection(phraseMediaCollectionName)
          .doc('${docId}_$i')
          .get();
      if (!chunkDoc.exists) return null;
      final encoded = chunkDoc.data()?['data'] as String?;
      if (encoded == null || encoded.isEmpty) return null;
      builder.add(base64Decode(encoded));
    }
    final bytes = builder.takeBytes();
    if (bytes.isEmpty) return null;
    await target.parent.create(recursive: true);
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  } catch (e, st) {
    debugPrint('Phrase media Firestore download failed: $e\n$st');
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

  final uri = Uri.tryParse(lower);
  final path = uri?.path ?? '';
  final host = uri?.host ?? '';
  bool has(String ext) =>
      lower.endsWith(ext) || path.endsWith(ext) || host.endsWith(ext);

  if (has('.mp4')) return '.mp4';
  if (has('.webm')) return '.webm';
  if (has('.mov')) return '.mov';
  if (has('.m4v')) return '.m4v';
  if (has('.png')) return '.png';
  if (has('.webp')) return '.webp';
  if (has('.gif')) return '.gif';
  if (has('.jpeg') || has('.jpg')) return '.jpg';
  if (isPhraseVideoPath(source)) return '.mp4';
  return '.jpg';
}
