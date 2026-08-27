import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:video_player/video_player.dart';

import '../core/theme/theme_tokens.dart';
import '../core/utils/phrase_image_storage.dart';
import '../core/utils/phrase_video_poster.dart';
import '../core/utils/phrase_video_speak_sync.dart';

export '../core/utils/phrase_image_storage.dart' show isPhraseVideoPath;

/// Serializes hardware video decoders. Cheap Unisoc chips can hold ~1 AVC
/// decoder; overlapping initialize() wedges playback for every card.
class _VideoInitGate {
  static const _max = 1;
  static int _active = 0;
  static final _waiters = Queue<Completer<void>>();

  static Future<void> acquire() async {
    while (_active >= _max) {
      final c = Completer<void>();
      _waiters.add(c);
      await c.future;
    }
    _active++;
  }

  static void release() {
    _active = (_active - 1).clamp(0, _max);
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
    }
  }
}

/// Displays a phrase image or muted video preview.
///
/// Videos are copied into app documents on first load. The first decoded
/// frame is saved as a PNG poster so later visits skip the decoder until Speak.
class PhraseImage extends StatefulWidget {
  const PhraseImage({
    super.key,
    required this.imagePath,
    required this.theme,
    this.aspectRatio = 1.35,
    this.fill = false,
    this.playing = false,
    this.keepReady = false,
  });

  final String? imagePath;
  final TapTalkThemeToken theme;
  final double aspectRatio;
  final bool fill;
  final bool playing;
  /// View dialog: keep a paused 720p decoder so Speak starts immediately.
  final bool keepReady;

  @override
  State<PhraseImage> createState() => _PhraseImageState();
}

class _PhraseImageState extends State<PhraseImage> {
  String? _resolvedPath;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    final raw = widget.imagePath?.trim();
    if (raw != null && isPhraseVideoPath(raw)) {
      final cached = cachedPhraseImagePathSync(raw);
      final existing = existingPhraseImagePath(raw);
      final playable = (cached != null && !isRemotePhraseImagePath(cached))
          ? cached
          : (existing != null && !isRemotePhraseImagePath(existing)
              ? existing
              : (raw.toLowerCase().startsWith('assets/') ? raw : null));
      _resolvedPath = playable;
      _resolving = false;
    } else {
      _resolvedPath = existingPhraseImagePath(widget.imagePath);
    }
    _resolvePath();
  }

  @override
  void didUpdateWidget(covariant PhraseImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      final raw = widget.imagePath?.trim();
      if (raw != null && isPhraseVideoPath(raw)) {
        final cached = cachedPhraseImagePathSync(raw);
        final existing = existingPhraseImagePath(raw);
        final playable = (cached != null && !isRemotePhraseImagePath(cached))
            ? cached
            : (existing != null && !isRemotePhraseImagePath(existing)
                ? existing
                : (raw.toLowerCase().startsWith('assets/') ? raw : null));
        _resolvedPath = playable;
        _resolving = false;
      } else {
        _resolvedPath = existingPhraseImagePath(widget.imagePath);
      }
      _resolvePath();
    }
  }

  Future<void> _resolvePath() async {
    final raw = widget.imagePath?.trim();
    if (raw == null || raw.isEmpty) {
      if (mounted) {
        setState(() {
          _resolvedPath = null;
          _resolving = false;
        });
      }
      return;
    }

    if (isPhraseVideoPath(raw)) {
      // Sticky path: swapping cache/asset remounts the player and drops posters.
      final sticky = _resolvedPath ??
          cachedPhraseImagePathSync(raw) ??
          existingPhraseImagePath(raw) ??
          (raw.toLowerCase().startsWith('assets/') ? raw : null);
      // Never treat a remote/fs-media ref as a playable sticky path.
      final stickyPlayable = (sticky != null && !isRemotePhraseImagePath(sticky))
          ? sticky
          : null;
      if (stickyPlayable != null) {
        if (mounted && (_resolvedPath != stickyPlayable || _resolving)) {
          setState(() {
            _resolvedPath = stickyPlayable;
            _resolving = false;
          });
        }
        unawaited(ensureLocalPhraseMediaPath(raw));
        unawaited(warmPhraseVideoPosterDirectory());
        return;
      }

      if (mounted) setState(() => _resolving = true);
      final local = await ensureLocalPhraseMediaPath(raw);
      if (!mounted) return;

      String? playable = local;
      if (playable != null && isRemotePhraseImagePath(playable)) {
        playable = null;
      }
      if (playable != null &&
          !playable.toLowerCase().startsWith('assets/') &&
          !isRemotePhraseImagePath(playable) &&
          !kIsWeb &&
          !File(playable).existsSync()) {
        playable = raw.toLowerCase().startsWith('assets/') ? raw : null;
      }

      setState(() {
        _resolvedPath = playable ??
            (raw.toLowerCase().startsWith('assets/') ? raw : null);
        _resolving = false;
      });
      return;
    }

    if (raw.toLowerCase().startsWith('assets/')) {
      if (mounted && _resolvedPath != raw) {
        setState(() => _resolvedPath = raw);
      }
      return;
    }

    final immediate = existingPhraseImagePath(raw);
    if (immediate != null) {
      if (mounted && _resolvedPath != immediate) {
        setState(() => _resolvedPath = immediate);
      }
      return;
    }

    if (mounted) setState(() => _resolving = true);
    await warmPhraseImageCacheDirectory();
    final local = await ensureLocalPhraseMediaPath(raw);
    if (!mounted) return;
    setState(() {
      _resolvedPath = local ??
          (isFirestorePhraseMediaPath(raw) || isRemotePhraseImagePath(raw)
              ? null
              : raw);
      _resolving = false;
    });
  }

  void _cacheAfterNetworkLoad(String raw) {
    if (!isRemotePhraseImagePath(raw)) return;
    cachePhraseImageLocally(raw).then((local) {
      if (!mounted || local == null || local == raw) return;
      if (_resolvedPath == local) return;
      if (_resolvedPath != null && !isRemotePhraseImagePath(_resolvedPath!)) {
        return;
      }
      setState(() => _resolvedPath = local);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fill) return SizedBox.expand(child: _buildMedia());
    return AspectRatio(aspectRatio: widget.aspectRatio, child: _buildMedia());
  }

  Widget _buildMedia() {
    final raw = widget.imagePath?.trim();
    if (raw == null || raw.isEmpty) {
      return _Placeholder(theme: widget.theme);
    }

    if (isPhraseVideoPath(raw)) {
      final path = _resolvedPath ??
          (raw.toLowerCase().startsWith('assets/') ? raw : null);
      if (path == null || isRemotePhraseImagePath(path)) {
        return _Placeholder(
          theme: widget.theme,
          icon: Icons.videocam_outlined,
        );
      }
      return RepaintBoundary(
        child: _PhraseVideoView(
          key: ValueKey('video_${raw}_$path'),
          path: path,
          sourceKey: raw,
          assetFallback: raw.toLowerCase().startsWith('assets/') ? raw : null,
          theme: widget.theme,
          playing: widget.playing,
          keepReady: widget.keepReady,
        ),
      );
    }

    final path = _resolvedPath ?? existingPhraseImagePath(raw) ?? raw;
    final lower = path.toLowerCase();
    if (isFirestorePhraseMediaPath(path) || _resolving) {
      return _Placeholder(theme: widget.theme);
    }
    if (lower.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _Placeholder(theme: widget.theme),
      );
    }
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('blob:')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        gaplessPlayback: true,
        headers: const {'User-Agent': 'TapTalk/1.0'},
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _Placeholder(theme: widget.theme);
        },
        frameBuilder: (context, child, frame, sync) {
          if (frame != null) _cacheAfterNetworkLoad(raw);
          if (sync || frame != null) return child;
          return _Placeholder(theme: widget.theme);
        },
        errorBuilder: (_, _, _) => _Placeholder(theme: widget.theme),
      );
    }
    if (!kIsWeb) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _Placeholder(theme: widget.theme),
        );
      }
    }
    return _Placeholder(theme: widget.theme);
  }
}

class _PhraseVideoView extends StatefulWidget {
  const _PhraseVideoView({
    super.key,
    required this.path,
    required this.sourceKey,
    required this.theme,
    required this.playing,
    this.keepReady = false,
    this.assetFallback,
  });

  final String path;
  /// Stable key for the first-frame poster (original phrase imagePath).
  final String sourceKey;
  final String? assetFallback;
  final TapTalkThemeToken theme;
  final bool playing;
  final bool keepReady;

  @override
  State<_PhraseVideoView> createState() => _PhraseVideoViewState();
}

class _PhraseVideoViewState extends State<_PhraseVideoView>
    with AutomaticKeepAliveClientMixin {
  /// Newest Speak clip wins the decoder; older cards yield immediately.
  static int _playbackEpoch = 0;
  static _PhraseVideoViewState? _activePlayback;

  final GlobalKey _captureKey = GlobalKey();
  VideoPlayerController? _controller;
  int _myEpoch = 0;
  bool _ready = false;
  /// Frozen first-frame PNG. Decoder is released after capture so other
  /// on-screen cards can load. Playback uses a live player only while speaking.
  String? _posterPath;
  bool _runToEnd = false;
  int _gen = 0;
  bool _gateHeld = false;
  bool _initializing = false;
  int _failCount = 0;
  Timer? _retryTimer;
  /// True once decoded frames are actually on screen (not a frozen first frame
  /// while the clock has already run ahead).
  bool _pictureReady = false;

  String get _posterKey => widget.sourceKey;

  @override
  bool get wantKeepAlive => _posterPath != null;

  @override
  void initState() {
    super.initState();
    unawaited(warmPhraseVideoPosterDirectory().then((_) {
      if (!mounted) return;
      final poster = cachedPhraseVideoPosterPathSync(_posterKey);
      if (poster == null) return;
      setState(() {
        _posterPath = poster;
        _ready = true;
      });
      updateKeepAlive();
      if (widget.playing) unawaited(_ensurePlaying());
    }));
    _init();
  }

  @override
  void didUpdateWidget(covariant _PhraseVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _disposeController();
      _failCount = 0;
      _posterPath = cachedPhraseVideoPosterPathSync(_posterKey);
      _ready = _posterPath != null;
      _init();
      return;
    }
    if (widget.playing) {
      if (!oldWidget.playing || !_hasLivePlayer) {
        unawaited(_ensurePlaying());
      }
    } else if (oldWidget.playing && !widget.playing) {
      // Speak ended: keep the clip running until its real end.
      if (!_clipStillPlaying()) {
        unawaited(_freeze());
      }
    }
  }

  VideoPlayerController _controllerForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.startsWith('assets/')) {
      return VideoPlayerController.asset(
        path,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
    }
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return VideoPlayerController.networkUrl(
        Uri.parse(path),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
    }
    return VideoPlayerController.file(
      File(path),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
  }

  bool get _hasLivePlayer =>
      _controller != null &&
      _controller!.value.isInitialized &&
      !_controller!.value.hasError;

  bool _clipStillPlaying() {
    if (!_runToEnd || !_hasLivePlayer) return false;
    final c = _controller!;
    final d = c.value.duration;
    if (d <= Duration.zero) return false;
    return c.value.position < d - const Duration(milliseconds: 200);
  }

  void _claimPlayback() {
    _myEpoch = ++_playbackEpoch;
    final prev = _activePlayback;
    _activePlayback = this;
    if (prev != null && prev != this) {
      prev._yieldPlayback();
    }
  }

  void _yieldPlayback() {
    if (!mounted) return;
    if (_myEpoch == _playbackEpoch) return;
    _runToEnd = false;
    unawaited(_freeze());
  }

  void _clearActivePlayback() {
    if (_activePlayback == this) _activePlayback = null;
  }

  Future<void> _ensurePlaying() async {
    _claimPlayback();
    var waited = 0;
    while (_initializing && waited < 80) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      waited++;
    }
    if (!_hasLivePlayer) {
      await _initPlayer();
    }
    if (!mounted) return;
    await _startFullClip();
  }

  Future<void> _init() async {
    if (_hasLivePlayer) return;
    if (_initializing) return;

    await warmPhraseVideoPosterDirectory();
    final poster = _posterPath ?? cachedPhraseVideoPosterPathSync(_posterKey);
    if (poster != null && mounted) {
      setState(() {
        _posterPath = poster;
        _ready = true;
      });
      updateKeepAlive();
    }

    if (widget.playing || widget.keepReady) {
      await _initPlayer();
      return;
    }
    if (poster != null) return;
    await _initPlayer();
  }

  Future<void> _initPlayer() async {
    if (_hasLivePlayer) return;
    if (!widget.playing && !widget.keepReady && _posterPath != null) return;
    if (_initializing) return;
    _initializing = true;

    final gen = ++_gen;

    await _VideoInitGate.acquire();
    if (!mounted || gen != _gen) {
      _initializing = false;
      _VideoInitGate.release();
      return;
    }
    if (_hasLivePlayer) {
      _initializing = false;
      _VideoInitGate.release();
      return;
    }
    _gateHeld = true;

    final path = widget.path;
    try {
      final local = await ensureLocalPhraseMediaPath(path) ?? path;
      if (!mounted || gen != _gen) {
        return;
      }

      var playPath = local;
      if (isRemotePhraseImagePath(playPath)) {
        if (path.toLowerCase().startsWith('assets/')) {
          playPath = path;
        } else if (widget.assetFallback != null) {
          playPath = widget.assetFallback!;
        } else {
          throw StateError('Video is not available offline: $path');
        }
      }

      var controller = _controllerForPath(playPath);
      try {
        await controller.initialize().timeout(const Duration(seconds: 12));
      } catch (_) {
        await _disposeControllerInstance(controller);
        final fallback = widget.assetFallback;
        if (fallback != null &&
            fallback != playPath &&
            fallback.toLowerCase().startsWith('assets/')) {
          playPath = fallback;
          controller = _controllerForPath(playPath);
          await controller.initialize().timeout(const Duration(seconds: 12));
        } else {
          rethrow;
        }
      }

      if (!mounted || gen != _gen) {
        await _disposeControllerInstance(controller);
        return;
      }

      await controller.setVolume(0);
      await controller.setLooping(false);
      if (controller.value.position > Duration.zero) {
        await controller.seekTo(Duration.zero);
      }
      if (widget.playing) {
        await _prerollDecoder(controller);
        if (!mounted || gen != _gen) {
          await _disposeControllerInstance(controller);
          return;
        }
        controller.addListener(_onTick);
        _controller = controller;
        _failCount = 0;
        if (mounted && gen == _gen) {
          setState(() => _ready = true);
          updateKeepAlive();
        }
        await _startFullClip();
        if (_posterPath == null) await _capturePoster(gen);
        return;
      }

      await _prerollDecoder(controller);

      controller.addListener(_onTick);
      _controller = controller;
      _failCount = 0;
      if (mounted && gen == _gen) {
        setState(() => _ready = true);
        updateKeepAlive();
      }

      await _capturePoster(gen);
      if (!mounted || gen != _gen) return;
      if (widget.playing) {
        await _startFullClip();
      } else if (!widget.keepReady) {
        final missedPoster = _posterPath == null;
        await _releasePlayerKeepReady();
        if (missedPoster && mounted && _failCount < 3) {
          _failCount++;
          _retryTimer?.cancel();
          _retryTimer = Timer(Duration(milliseconds: 500 * _failCount), () {
            if (!mounted) return;
            _init();
          });
        }
      }
    } catch (e, st) {
      debugPrint('Phrase video init failed ($path): $e\n$st');
      final c = _controller;
      _controller = null;
      await _disposeControllerInstance(c);
      if (mounted && gen == _gen) {
        _failCount++;
        if (_ready && _posterPath == null) {
          setState(() => _ready = false);
        }
        if (_failCount <= 2) {
          final delayMs = (800 * _failCount).clamp(800, 3000);
          _retryTimer?.cancel();
          _retryTimer = Timer(Duration(milliseconds: delayMs), () {
            if (!mounted) return;
            _init();
          });
        }
      }
    } finally {
      _initializing = false;
      if (!_hasLivePlayer) {
        _releaseGate();
      }
    }
  }

  Future<void> _capturePoster(int gen) async {
    if (_posterPath != null) return;
    for (var attempt = 0; attempt < 3; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(
        Duration(milliseconds: attempt == 0 ? 32 : 80),
      );
      if (!mounted || gen != _gen) return;
      try {
        final boundary = _captureKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary == null || !boundary.hasSize) continue;
        final videoSize = _controller?.value.size ?? Size.zero;
        final boxW = boundary.size.width;
        final targetW = videoSize.width > 0 ? videoSize.width : 1280;
        final pixelRatio = boxW <= 0
            ? 3.0
            : (targetW / boxW).clamp(2.0, 6.0);
        final image = await boundary.toImage(pixelRatio: pixelRatio);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        if (bytes == null) continue;
        final saved = await savePhraseVideoPosterBytes(
          _posterKey,
          bytes.buffer.asUint8List(),
        );
        if (!mounted || gen != _gen) return;
        if (saved == null) continue;
        _posterPath = saved;
        if (mounted) setState(() {});
        updateKeepAlive();
        return;
      } catch (e, st) {
        debugPrint('Phrase video poster capture failed ($_posterKey): $e\n$st');
      }
    }
  }

  Future<void> _disposeControllerInstance(VideoPlayerController? c) async {
    c?.removeListener(_onTick);
    try {
      await c?.dispose();
    } catch (_) {}
    // Unisoc needs the previous AVC decoder fully gone before the next init.
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  Future<void> _releasePlayerKeepReady() async {
    _clearActivePlayback();
    _retryTimer?.cancel();
    _gen++;
    _runToEnd = false;
    _pictureReady = false;
    final c = _controller;
    _controller = null;
    await _disposeControllerInstance(c);
    _releaseGate();
    if (mounted) setState(() {});
    updateKeepAlive();
  }

  void _releaseGate() {
    if (!_gateHeld) return;
    _gateHeld = false;
    _VideoInitGate.release();
  }

  Future<void> _prerollDecoder(VideoPlayerController controller) async {
    try {
      await controller.setLooping(false);
      await controller.play();
      await WidgetsBinding.instance.endOfFrame;
      for (var i = 0; i < 12; i++) {
        if (controller.value.size.width > 0 &&
            controller.value.position > Duration.zero) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      await controller.pause();
      await controller.seekTo(Duration.zero);
      await _waitUntilNearStart(controller);
    } catch (_) {}
  }

  Future<void> _waitUntilNearStart(VideoPlayerController c) async {
    for (var i = 0; i < 16; i++) {
      if (!c.value.isBuffering &&
          c.value.position <= const Duration(milliseconds: 80)) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  Future<void> _waitForRealPlayback(VideoPlayerController c) async {
    final dur = c.value.duration;
    for (var i = 0; i < 24; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      final pos = c.value.position;
      if (dur > Duration.zero && pos > Duration(milliseconds: dur.inMilliseconds ~/ 3)) {
        try {
          await c.pause();
          await c.seekTo(Duration.zero);
          await _waitUntilNearStart(c);
          await c.play();
        } catch (_) {}
        continue;
      }
      if (c.value.isPlaying &&
          !c.value.isBuffering &&
          pos >= const Duration(milliseconds: 16) &&
          pos < const Duration(milliseconds: 400)) {
        return;
      }
    }
  }

  Future<void> _startFullClip() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    _claimPlayback();
    _runToEnd = true;
    _pictureReady = false;
    try {
      await c.setLooping(false);
      await c.pause();
      await c.seekTo(Duration.zero);
      await _waitUntilNearStart(c);
      await c.play();
      await _waitForRealPlayback(c);
      if (mounted) setState(() => _pictureReady = true);
      PhraseVideoSpeakSync.signalReady();
    } catch (_) {
      PhraseVideoSpeakSync.signalReady();
    }
  }

  void _onTick() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.hasError) {
      _runToEnd = false;
      final broken = _controller;
      _controller = null;
      if (_posterPath == null) _ready = false;
      unawaited(() async {
        await _disposeControllerInstance(broken);
        _releaseGate();
      }());
      if (mounted) {
        setState(() {});
        updateKeepAlive();
        if (_posterPath == null) {
          _retryTimer?.cancel();
          _retryTimer = Timer(const Duration(milliseconds: 800), () {
            if (!mounted) return;
            _init();
          });
        }
      }
      return;
    }

    if (_myEpoch != _playbackEpoch) {
      _runToEnd = false;
      unawaited(_freeze());
      return;
    }
    if (!_runToEnd) return;
    if (c.value.isPlaying) return;
    if (!_pictureReady) return;
    final d = c.value.duration;
    if (d <= Duration.zero) return;
    if (c.value.position >= d - const Duration(milliseconds: 200)) {
      _runToEnd = false;
      unawaited(_freeze());
    }
  }

  Future<void> _freeze() async {
    _clearActivePlayback();
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.pause();
    } catch (_) {}
    _pictureReady = false;
    if (mounted) setState(() {});
    if (!widget.playing) {
      if (widget.keepReady) return;
      await _releasePlayerKeepReady();
    }
  }

  void _disposeController() {
    _clearActivePlayback();
    _retryTimer?.cancel();
    _gen++;
    _runToEnd = false;
    _pictureReady = false;
    _ready = false;
    final c = _controller;
    _controller = null;
    final held = _gateHeld;
    _gateHeld = false;
    unawaited(() async {
      await _disposeControllerInstance(c);
      if (held) _VideoInitGate.release();
    }());
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = _controller;
    final live = _hasLivePlayer && c != null;
    final poster = _posterPath;

    Widget? video;
    if (live) {
      final size = c.value.size;
      video = ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.width == 0 ? 1 : size.width,
            height: size.height == 0 ? 1 : size.height,
            child: VideoPlayer(c),
          ),
        ),
      );
    }

    Widget? frame;
    if (poster != null) {
      frame = Image.file(
        File(poster),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
        errorBuilder: (_, _, _) => const SizedBox.expand(),
      );
    }

    if (video != null || frame != null) {
      return ColoredBox(
        color: Colors.black,
        child: RepaintBoundary(
          key: _captureKey,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ?frame,
              // View dialog keeps a paused player — use that first frame so
              // the crop matches playback (card posters are a different aspect).
              if (_pictureReady || frame == null || widget.keepReady) ?video,
            ],
          ),
        ),
      );
    }
    return _Placeholder(
      theme: widget.theme,
      icon: Icons.videocam_outlined,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.theme,
    this.icon = Icons.image_outlined,
  });

  final TapTalkThemeToken theme;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Icon(
          icon,
          size: 40,
          color: theme.textMain.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
