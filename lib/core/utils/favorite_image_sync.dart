import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'phrase_image_cloud_sync.dart';
import 'phrase_image_storage.dart';

const int _maxFavoriteImageBytes = 700000;

/// Prepares a favorite image for Firestore sync (Storage URL or base64 fallback).
Future<String?> resolveFavoriteImageForCloudExport(
  String? imagePath,
  String ownerFirebaseUid,
) async {
  if (imagePath == null || imagePath.trim().isEmpty) return null;
  final trimmed = imagePath.trim();
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('assets/') ||
      lower.startsWith('data:')) {
    return trimmed;
  }
  if (kIsWeb) return null;

  final uploaded = await resolveImagePathForCloudSync(trimmed, ownerFirebaseUid);
  if (uploaded != null && uploaded.trim().isNotEmpty) {
    return uploaded;
  }

  final file = File(trimmed);
  if (!await file.exists()) return null;
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty || bytes.length > _maxFavoriteImageBytes) return null;

  final ext = p.extension(trimmed).toLowerCase();
  final mime = switch (ext) {
    '.png' => 'image/png',
    '.webp' => 'image/webp',
    '.gif' => 'image/gif',
    _ => 'image/jpeg',
  };
  return 'data:$mime;base64,${base64Encode(bytes)}';
}

/// Stores a cloud favorite image locally so favorites cards can display it offline.
Future<String?> resolveFavoriteImageFromCloud(String? imagePath) async {
  return resolveStoredPhraseImagePath(imagePath);
}
