import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Uploads local phrase images to Firebase Storage for cross-device sync.
Future<String?> resolveImagePathForCloudSync(
  String? imagePath,
  String ownerFirebaseUid,
) async {
  if (imagePath == null || imagePath.trim().isEmpty) return null;
  final trimmed = imagePath.trim();
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('assets/')) {
    return trimmed;
  }
  if (kIsWeb) return null;

  final uid = ownerFirebaseUid.trim();
  if (uid.isEmpty) return null;

  final file = File(trimmed);
  if (!await file.exists()) return null;

  try {
    final ext = p.extension(trimmed);
    final safeExt = ext.isEmpty || ext.length > 8 ? '.jpg' : ext;
    final objectName = '${const Uuid().v4()}$safeExt';
    final ref = FirebaseStorage.instance
        .ref()
        .child('phrase_images')
        .child(uid)
        .child(objectName);
    await ref.putFile(file);
    return await ref.getDownloadURL();
  } catch (e, st) {
    debugPrint('Phrase image cloud upload failed: $e\n$st');
    return null;
  }
}
