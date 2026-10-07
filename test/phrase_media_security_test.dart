import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
// FlutterFire exposes its test doubles through its platform interface packages.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_storage_platform_interface/firebase_storage_platform_interface.dart';
import 'package:flutter_application_1/core/utils/phrase_image_cloud_sync.dart';
import 'package:flutter_application_1/core/utils/phrase_image_storage.dart';
import 'package:flutter_application_1/core/theme/theme_tokens.dart';
import 'package:flutter_application_1/widgets/phrase_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _Firebase extends FirebasePlatform {
  final _app = FirebaseAppPlatform(
    defaultFirebaseAppName,
    const FirebaseOptions(
      apiKey: 'test',
      appId: 'test',
      messagingSenderId: 'test',
      projectId: 'test',
      storageBucket: 'test.appspot.com',
    ),
  );

  @override
  List<FirebaseAppPlatform> get apps => [_app];
  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) => _app;
}

class _Paths extends PathProviderPlatform {
  _Paths(this.directory);
  final Directory directory;
  @override
  Future<String?> getApplicationDocumentsPath() async => directory.path;
}

class _Storage extends FirebaseStoragePlatform {
  _Storage() : super(bucket: 'test.appspot.com');
  Uint8List? bytes = Uint8List.fromList([1, 2, 3]);
  Object? error;
  final requests = <({String path, int limit})>[];

  @override
  FirebaseStoragePlatform delegateFor({
    required FirebaseApp app,
    required String bucket,
  }) => this;

  @override
  ReferencePlatform ref(String path) => _Reference(this, path);
}

class _Reference extends ReferencePlatform {
  _Reference(super.storage, super.path);

  @override
  Future<Uint8List?> getData(int maxSize) async {
    final fake = storage as _Storage;
    fake.requests.add((path: fullPath, limit: maxSize));
    if (fake.error != null) throw fake.error!;
    return fake.bytes;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = _Storage();
  late Directory directory;
  late FirebasePlatform oldFirebase;
  late FirebaseStoragePlatform oldStorage;
  late PathProviderPlatform oldPaths;

  setUpAll(() {
    oldFirebase = FirebasePlatform.instance;
    oldStorage = FirebaseStoragePlatform.instance;
    oldPaths = PathProviderPlatform.instance;
    FirebasePlatform.instance = _Firebase();
    FirebaseStoragePlatform.instance = storage;
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('taptalk-media-test-');
    PathProviderPlatform.instance = _Paths(directory);
    storage.bytes = Uint8List.fromList([1, 2, 3]);
    storage.error = null;
    storage.requests.clear();
  });
  tearDown(() async => directory.delete(recursive: true));
  tearDownAll(() {
    FirebasePlatform.instance = oldFirebase;
    FirebaseStoragePlatform.instance = oldStorage;
    PathProviderPlatform.instance = oldPaths;
  });

  test(
    'authenticated references route as remote media and retain video type',
    () {
      const image = 'gs://test.appspot.com/phrase_images/learner/image.png';
      const video = 'gs://test.appspot.com/phrase_images/learner/video.mp4';
      expect(isFirebaseStoragePhraseMediaPath(image), isTrue);
      expect(isRemotePhraseImagePath(image), isTrue);
      expect(isFirestorePhraseMediaPath(image), isFalse);
      expect(isPhraseVideoPath(video), isTrue);
      expect(isPhraseVideoPath(image), isFalse);
    },
  );

  test(
    'new Storage references use bounded authenticated SDK downloads',
    () async {
      const ref = 'gs://test.appspot.com/phrase_images/learner/image.png';
      final local = await cachePhraseImageLocally(ref);
      expect(local, isNotNull);
      expect(await File(local!).readAsBytes(), [1, 2, 3]);
      expect(local, endsWith('.png'));
      expect(storage.requests.single.path, 'phrase_images/learner/image.png');
      expect(storage.requests.single.limit, 20 * 1024 * 1024);
      expect(await cachePhraseImageLocally(ref), local);
      expect(storage.requests, hasLength(1));
    },
  );

  test('persist and cloud sync keep the authenticated reference', () async {
    const ref = 'gs://test.appspot.com/phrase_images/learner/video.mp4';
    expect(await persistPhraseImageIfNeeded(ref), ref);
    expect(await resolveStoredPhraseImagePath(ref), ref);
    expect(await resolveImagePathForCloudSync(ref, 'learner'), ref);
    expect(cachedPhraseImagePathSync(ref), endsWith('.mp4'));
    expect(storage.requests, hasLength(1));
  });

  test(
    'legacy bearer URLs are scrubbed and fetched through Storage Auth',
    () async {
      const url =
          'https://firebasestorage.googleapis.com/v0/b/test.appspot.com/o/'
          'phrase_images%2Flearner%2Fimage.png?alt=media&token=old-secret';
      const ref = 'gs://test.appspot.com/phrase_images/learner/image.png';
      expect(authenticatedPhraseMediaReference(url), ref);
      expect(await resolveImagePathForCloudSync(url, 'learner'), ref);
      final local = await cachePhraseImageLocally(url);
      expect(local, isNotNull);
      expect(storage.requests.single.path, 'phrase_images/learner/image.png');
      expect(await cachePhraseImageLocally(ref), local);
      expect(await persistPhraseImageIfNeeded(url), ref);
      expect(await resolveStoredPhraseImagePath(url), ref);
      expect(cachedPhraseImagePathSync(url), local);
      expect(storage.requests, hasLength(1));
    },
  );

  test('unrelated HTTPS media does not get reinterpreted as Firebase media', () {
    for (final url in [
      'https://example.com/image.png',
      'https://firebasestorage.googleapis.com.evil.test/v0/b/test/o/image.png',
      'https://firebasestorage.googleapis.com/v0/b/test/o/',
      'https://user@firebasestorage.googleapis.com/v0/b/test/o/image.png',
    ]) {
      expect(authenticatedPhraseMediaReference(url), isNull, reason: url);
    }
  });

  test('denied downloads never become HTTP downloads or cached files', () async {
    const ref = 'gs://test.appspot.com/phrase_images/learner/private.jpg';
    storage.error = FirebaseException(
      plugin: 'firebase_storage',
      code: 'unauthorized',
    );
    expect(await cachePhraseImageLocally(ref), isNull);
    expect(cachedPhraseImagePathSync(ref), isNull);
    expect(existingPhraseImagePath(ref), isNull);
    expect(storage.requests, hasLength(1));
    // Offline persistence keeps the cloud identity for a later authorized read.
    expect(await resolveStoredPhraseImagePath(ref), ref);
  });

  testWidgets('denied Firebase images cannot fall back to Image.network', (
    tester,
  ) async {
    storage.error = FirebaseException(
      plugin: 'firebase_storage',
      code: 'unauthorized',
    );
    for (final ref in [
      'gs://test.appspot.com/phrase_images/learner/private.png',
      'https://firebasestorage.googleapis.com/v0/b/test.appspot.com/o/'
          'phrase_images%2Flearner%2Fprivate.png?alt=media&token=old-secret',
    ]) {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: PhraseImage(
              key: ValueKey(ref),
              imagePath: ref,
              theme: TapTalkThemes.appDefault,
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pump();
      expect(find.byType(Image), findsNothing, reason: ref);
      expect(tester.takeException(), isNull);
    }
    expect(storage.requests, hasLength(2));
  });

  test(
    'empty and oversized SDK responses cannot create a cached file',
    () async {
      const empty = 'gs://test.appspot.com/phrase_images/learner/empty.jpg';
      storage.bytes = Uint8List(0);
      expect(await cachePhraseImageLocally(empty), isNull);
      expect(cachedPhraseImagePathSync(empty), isNull);
      const large = 'gs://test.appspot.com/phrase_images/learner/large.jpg';
      storage.bytes = Uint8List(maxPhraseMediaDownloadBytes + 1);
      expect(await cachePhraseImageLocally(large), isNull);
      expect(cachedPhraseImagePathSync(large), isNull);
    },
  );

  test(
    'malformed references cannot trigger a Storage or HTTP request',
    () async {
      for (final ref in [
        'gs://',
        'gs://test.appspot.com/',
        'gs://test.appspot.com/image.png?token=secret',
        'gs://user@test.appspot.com/image.png',
        'gs://test.appspot.com:123/image.png',
        'gs://test.appspot.com/phrase_images//image.png',
      ]) {
        expect(isFirebaseStoragePhraseMediaPath(ref), isFalse, reason: ref);
        expect(await cachePhraseImageLocally(ref), isNull, reason: ref);
        expect(await resolveImagePathForCloudSync(ref, 'learner'), isNull);
      }
      expect(storage.requests, isEmpty);
    },
  );
}
