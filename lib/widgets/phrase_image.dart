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

export '../core/utils/phrase_image_storage.dart' show isPhraseVideoPath;

/// Limits how many video decoders initialize at once (not how many stay alive).
class _VideoInitGate {
  static const _max = 2;
  static int _active = 0;
  static final _waiters = Queue<Completer<void>>();

  static Future<void> acquire() async {
    if (_active < _max) {
      _active++;
      return;
    }
    final c = Completer<void>();
    _waiters.add(c);
    await c.future;
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
/// Videos are copied into app documents on first load, then played from that
/// local file so they work offline. Once a video is ready it stays retained
/// (keep-alive) — no park/evict flicker while scrolling.
class PhraseImage extends StatefulWidget {
  const PhraseImage({
    super.key,
    required this.imagePath,
    required this.theme,
    this.aspectRatio = 1.35,
    this.fill = false,
    this.playing = false,
  });

  final String? imagePath;
  final TapTalkThemeToken theme;
  final double aspectRatio;
  final bool fill;
  final bool playing;

  @override
  State<PhraseImage> createState() => _PhraseImageState();
}

class _PhraseImageState extends State<PhraseImage> {
  String? _resolvedPath;
  bool _resolving = false;

  static bool _isHomeVideoAsset(String path) {
    final lower = path.toLowerCase();
    return lower.startsWith('assets/videos/home/') && isPhraseVideoPath(lower);
  }

  @override
  void initState() {
    super.initState();
    final raw = widget.imagePath?.trim();
    if (raw != null && _isHomeVideoAsset(raw)) {
      // Sticky path immediately so every Home card can start loading.
      _resolvedPath = cachedPhraseImagePathSync(raw) ?? raw;
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
      if (raw != null && _isHomeVideoAsset(raw)) {
        _resolvedPath = cachedPhraseImagePathSync(raw) ?? raw;
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
      // Home: sticky path. Never swap later — that remounts players.
      if (_isHomeVideoAsset(raw)) {
        final sticky = _resolvedPath ?? cachedPhraseImagePathSync(raw) ?? raw;
        if (mounted && (_resolvedPath != sticky || _resolving)) {
          setState(() {
            _resolvedPath = sticky;
            _resolving = false;
          });
        }
        unawaited(ensureLocalPhraseMediaPath(raw));
        unawaited(warmPhraseVideoPosterDirectory());
        return;
      }

      final cached = cachedPhraseImagePathSync(raw);
      if (cached != null) {
        if (mounted && _resolvedPath != cached) {
          setState(() {
            _resolvedPath = cached;
            _resolving = false;
          });
        }
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
          playable.toLowerCase().startsWith('assets/') &&
          isPhraseVideoPath(playable)) {
        // Materialize failed — still try asset playback.
      } else if (playable != null &&
          !playable.toLowerCase().startsWith('assets/') &&
          !isRemotePhraseImagePath(playable) &&
          !kIsWeb &&
          !File(playable).existsSync()) {
        playable = raw.toLowerCase().startsWith('assets/') ? raw : null;
      }

      setState(() {
        _resolvedPath = playable ??
            (raw.toLowerCase().startsWith('assets/') ? raw : local ?? raw);
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

    await warmPhraseImageCacheDirectory();
    final local = await ensureLocalPhraseMediaPath(raw);
    if (!mounted) return;
    setState(() => _resolvedPath = local ?? raw);
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
      final path = _resolvedPath ?? (_isHomeVideoAsset(raw) ? raw : null);
      if (path == null || isRemotePhraseImagePath(path)) {
        return _Placeholder(
          theme: widget.theme,
          icon: Icons.videocam_outlined,
        );
      }
      return RepaintBoundary(
        child: _PhraseVideoView(
          key: ValueKey('video_$raw'),
          path: path,
          assetFallback: raw.toLowerCase().startsWith('assets/') ? raw : null,
          theme: widget.theme,
          playing: widget.playing,
          // Home: keep-alive only after first frame so viewport cards can load.
          retainWhileAlive: !_isHomeVideoAsset(raw),
        ),
      );
    }

    final path = _resolvedPath ?? existingPhraseImagePath(raw) ?? raw;
    final lower = path.toLowerCase();
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
    required this.theme,
    required this.playing,
    this.assetFallback,
    this.retainWhileAlive = true,
  });

  final String path;
  final String? assetFallback;
  final TapTalkThemeToken theme;
  final bool playing;
  /// When false (Home), keep-alive only after [_ready].
  final bool retainWhileAlive;

  @override
  State<_PhraseVideoView> createState() => _PhraseVideoViewState();
}

class _PhraseVideoViewState extends State<_PhraseVideoView>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey _captureKey = GlobalKey();
  VideoPlayerController? _controller;
  bool _ready = false;
  /// Frozen first-frame PNG (Home). Frees the decoder so later cards can load
  /// while already-ready cards stay retained with no on/off flicker.
  String? _posterPath;
  bool _runToEnd = false;
  int _gen = 0;
  bool _gateHeld = false;
  bool _initializing = false;
  int _failCount = 0;
  Timer? _retryTimer;

  String get _posterKey => widget.assetFallback ?? widget.path;

  bool get _isHomeClip {
    final raw = _posterKey.toLowerCase();
    return raw.startsWith('assets/videos/home/') && isPhraseVideoPath(raw);
  }

  @override
  bool get wantKeepAlive => widget.retainWhileAlive || _ready;

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
      if (widget.playing || _runToEnd) unawaited(_initPlayer());
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
    if (!oldWidget.playing && widget.playing) {
      unawaited(_ensurePlaying());
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

  Future<void> _ensurePlaying() async {
    if (!_hasLivePlayer) {
      await _initPlayer();
    }
    if (!mounted) return;
    await _startFullClip();
  }

  Future<void> _init() async {
    if (_hasLivePlayer) return;
    if (_initializing) return;

    if (_isHomeClip) {
      await _loadHomePreview();
      return;
    }

    await _initPlayer();
  }

  Future<void> _loadHomePreview() async {
    _initializing = true;
    try {
      await warmPhraseVideoPosterDirectory();
      final poster =
          _posterPath ?? cachedPhraseVideoPosterPathSync(_posterKey);
      if (!mounted) return;
      if (poster != null) {
        setState(() {
          _posterPath = poster;
          _ready = true;
        });
        updateKeepAlive();
        if (widget.playing || _runToEnd) {
          await _initPlayer();
        }
        return;
      }
      await _initPlayer();
    } finally {
      _initializing = false;
    }
  }

  Future<void> _initPlayer() async {
    if (_hasLivePlayer) return;

    final gen = ++_gen;

    await _VideoInitGate.acquire();
    if (!mounted || gen != _gen) {
      _VideoInitGate.release();
      return;
    }
    if (_hasLivePlayer) {
      _VideoInitGate.release();
      return;
    }
    _gateHeld = true;

    final path = widget.path;
    try {
      final local = await ensureLocalPhraseMediaPath(path) ?? path;
      if (!mounted || gen != _gen) {
        _releaseGate();
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
        await controller.dispose();
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
        await controller.dispose();
        _releaseGate();
        return;
      }

      await controller.setVolume(0);
      await controller.setLooping(false);

      await controller.seekTo(Duration.zero);
      await controller.play();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted || gen != _gen) {
        await controller.dispose();
        _releaseGate();
        return;
      }
      if (!widget.playing && !_runToEnd) {
        await controller.pause();
        await controller.seekTo(Duration.zero);
      }

      controller.addListener(_onTick);
      _controller = controller;
      _failCount = 0;
      if (mounted && gen == _gen) {
        setState(() => _ready = true);
        updateKeepAlive();
      }
      if (widget.playing || _runToEnd) {
        await _startFullClip();
      } else if (_isHomeClip) {
        unawaited(_captureHomePosterAndRelease(gen));
      }
    } catch (e, st) {
      debugPrint('Phrase video init failed ($path): $e\n$st');
      final c = _controller;
      _controller = null;
      try {
        await c?.dispose();
      } catch (_) {}
      if (mounted && gen == _gen) {
        _failCount++;
        if (_ready && _posterPath == null) {
          setState(() => _ready = false);
        }
        final delayMs = (500 * _failCount).clamp(500, 3000);
        _retryTimer?.cancel();
        _retryTimer = Timer(Duration(milliseconds: delayMs), () {
          if (!mounted || gen != _gen) return;
          _init();
        });
      }
    } finally {
      _releaseGate();
    }
  }

  /// Snapshot the painted first frame (no native thumbnail plugin), cache it,
  /// then free the decoder so remaining Home cards can initialize.
  Future<void> _captureHomePosterAndRelease(int gen) async {
    if (!_isHomeClip || widget.playing || _runToEnd) return;
    if (_posterPath != null) {
      _releasePlayerKeepReady();
      return;
    }

    // Let the VideoPlayer paint at least one frame.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted || gen != _gen || widget.playing || _runToEnd) return;

    try {
      final boundary = _captureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null || !boundary.hasSize) return;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) return;
      final saved = await savePhraseVideoPosterBytes(
        _posterKey,
        bytes.buffer.asUint8List(),
      );
      if (!mounted || gen != _gen || widget.playing || _runToEnd) return;
      if (saved == null) return;
      _posterPath = saved;
      _releasePlayerKeepReady();
    } catch (e, st) {
      debugPrint('Home poster capture failed ($_posterKey): $e\n$st');
    }
  }

  void _releasePlayerKeepReady() {
    _retryTimer?.cancel();
    _gen++;
    _runToEnd = false;
    final c = _controller;
    _controller = null;
    c?.removeListener(_onTick);
    c?.dispose();
    _releaseGate();
    if (mounted) setState(() {});
    updateKeepAlive();
  }

  void _releaseGate() {
    if (!_gateHeld) return;
    _gateHeld = false;
    _VideoInitGate.release();
  }

  Future<void> _startFullClip() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    _runToEnd = true;
    try {
      await c.seekTo(Duration.zero);
      await c.setLooping(false);
      await c.play();
    } catch (_) {}
  }

  void _onTick() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.hasError) {
      _runToEnd = false;
      final broken = _controller;
      _controller = null;
      if (_posterPath == null) _ready = false;
      broken?.removeListener(_onTick);
      broken?.dispose();
      if (mounted) {
        setState(() {});
        updateKeepAlive();
        if (_posterPath == null) {
          _retryTimer?.cancel();
          _retryTimer = Timer(const Duration(milliseconds: 600), () {
            if (!mounted) return;
            _init();
          });
        }
      }
      return;
    }

    if (!_runToEnd) return;
    if (c.value.isPlaying) return;
    final d = c.value.duration;
    if (d <= Duration.zero) return;
    if (c.value.position >= d - const Duration(milliseconds: 200)) {
      _runToEnd = false;
      unawaited(_freeze());
    }
  }

  Future<void> _freeze() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.pause();
      await c.seekTo(Duration.zero);
    } catch (_) {}
    if (_isHomeClip && _posterPath != null && !widget.playing) {
      _releasePlayerKeepReady();
    }
  }

  void _disposeController() {
    _retryTimer?.cancel();
    _gen++;
    _runToEnd = false;
    _ready = false;
    final c = _controller;
    _controller = null;
    c?.removeListener(_onTick);
    c?.dispose();
    _releaseGate();
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
              ?video,
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
