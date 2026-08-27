import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../services/firebase_service.dart';
import 'phrase_image_storage.dart';
import 'phrase_video_poster.dart';

/// ~500KB binary → ~667KB base64, safely under Firestore's 1MB doc limit.
const int _firestoreChunkBytes = 500000;
const int _maxFirestoreMediaBytes = 20 * 1024 * 1024;

bool _storageUnavailableThisSession = false;

/// Uploads local phrase media for cross-device sync.
/// Prefers Firebase Storage; if Storage is blocked (e.g. Spark plan 402),
/// falls back to chunked Firestore docs that any signed-in student can read.
Future<String?> resolveImagePathForCloudSync(
  String? imagePath,
  String ownerFirebaseUid,
) async {
  if (imagePath == null || imagePath.trim().isEmpty) return null;
  final trimmed = imagePath.trim();
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('assets/') ||
      lower.startsWith('data:') ||
      isFirestorePhraseMediaPath(trimmed)) {
    return trimmed;
  }
  if (kIsWeb) return null;

  final uid = ownerFirebaseUid.trim();
  if (uid.isEmpty) return null;

  final file = File(trimmed);
  if (!await file.exists()) return null;

  final ext = p.extension(trimmed);
  final safeExt = ext.isEmpty || ext.length > 8
      ? (isPhraseVideoPath(trimmed) ? '.mp4' : '.jpg')
      : ext;
  final isVideo =
      isPhraseVideoPath(trimmed) || safeExt.toLowerCase() == '.mp4';
  final contentType = isVideo
      ? 'video/mp4'
      : switch (safeExt.toLowerCase()) {
          '.png' => 'image/png',
          '.webp' => 'image/webp',
          '.gif' => 'image/gif',
          _ => 'image/jpeg',
        };

  if (!_storageUnavailableThisSession && !isVideo) {
    try {
      final digest = sha256.convert(await file.readAsBytes()).toString();
      final objectName = '${digest.substring(0, 32)}$safeExt';
      final ref = FirebaseStorage.instance
          .ref()
          .child('phrase_images')
          .child(uid)
          .child(objectName);
      await ref.putFile(file).timeout(const Duration(seconds: 12));
      final url =
          await ref.getDownloadURL().timeout(const Duration(seconds: 8));
      if (url.trim().isNotEmpty) {
        await _seedLocalMediaForRemote(remoteRef: url, localPath: trimmed);
        return url;
      }
    } catch (e) {
      _storageUnavailableThisSession = true;
      debugPrint(
        'Firebase Storage unavailable for phrase media; '
        'using Firestore fallback. ($e)',
      );
    }
  }

  return _uploadPhraseMediaToFirestore(
    file: file,
    ownerFirebaseUid: uid,
    contentType: contentType,
    ext: safeExt,
  );
}

Future<void> _seedLocalMediaForRemote({
  required String remoteRef,
  required String localPath,
}) async {
  final cached = await seedPhraseMediaCacheFromLocal(
    remoteRef: remoteRef,
    localPath: localPath,
  );
  if (cached == null) return;
  if (!isPhraseVideoPath(localPath) && !isPhraseVideoPath(remoteRef)) return;
  final poster = cachedPhraseVideoPosterPathSync(localPath);
  if (poster == null) return;
  try {
    final bytes = await File(poster).readAsBytes();
    if (bytes.isEmpty) return;
    await savePhraseVideoPosterBytes(remoteRef, bytes);
  } catch (e, st) {
    debugPrint('Seed phrase video poster failed: $e\n$st');
  }
}

Future<String?> _uploadPhraseMediaToFirestore({
  required File file,
  required String ownerFirebaseUid,
  required String contentType,
  required String ext,
}) async {
  await FirebaseService.instance.initialize();
  if (!FirebaseService.instance.isAvailable) return null;

  try {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    if (bytes.length > _maxFirestoreMediaBytes) {
      debugPrint(
        'Phrase media too large for Firestore fallback '
        '(${bytes.length} bytes)',
      );
      return null;
    }

    // Stable id from file bytes so re-sync never invents a "new" video URL
    // (that was swapping media across devices / reloads).
    final digest = sha256.convert(bytes).toString();
    final docId = '${ownerFirebaseUid}_${digest.substring(0, 32)}';
    final mediaRef = '$phraseMediaScheme$docId$ext';
    final firestore = FirebaseFirestore.instance;
    final existing =
        await firestore.collection(phraseMediaCollectionName).doc(docId).get();
    if (existing.exists) {
      await _seedLocalMediaForRemote(
        remoteRef: mediaRef,
        localPath: file.path,
      );
      return mediaRef;
    }

    final chunkCount =
        math.max(1, (bytes.length / _firestoreChunkBytes).ceil());
    final writes = <Future<void>>[
      firestore.collection(phraseMediaCollectionName).doc(docId).set({
        'teacherFirebaseUid': ownerFirebaseUid,
        'contentType': contentType,
        'ext': ext,
        'chunkCount': chunkCount,
        'totalBytes': bytes.length,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    ];

    for (var i = 0; i < chunkCount; i++) {
      final start = i * _firestoreChunkBytes;
      final end = math.min(start + _firestoreChunkBytes, bytes.length);
      final chunk = bytes.sublist(start, end);
      writes.add(
        firestore.collection(phraseMediaCollectionName).doc('${docId}_$i').set({
          'teacherFirebaseUid': ownerFirebaseUid,
          'parentId': docId,
          'index': i,
          'data': base64Encode(chunk),
        }),
      );
    }

    for (var i = 0; i < writes.length; i += 4) {
      final end = math.min(i + 4, writes.length);
      await Future.wait(writes.sublist(i, end));
    }

    await _seedLocalMediaForRemote(remoteRef: mediaRef, localPath: file.path);
    return mediaRef;
  } catch (e, st) {
    debugPrint('Phrase media Firestore upload failed: $e\n$st');
    return null;
  }
}
