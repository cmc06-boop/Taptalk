import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/theme/theme_tokens.dart';
import '../core/utils/phrase_image_storage.dart';

/// Displays a phrase image from network URL, asset, or local file path.
class PhraseImage extends StatefulWidget {
  const PhraseImage({
    super.key,
    required this.imagePath,
    required this.theme,
    this.aspectRatio = 1.35,
    this.fill = false,
  });

  final String? imagePath;
  final TapTalkThemeToken theme;
  final double aspectRatio;
  final bool fill;

  @override
  State<PhraseImage> createState() => _PhraseImageState();
}

class _PhraseImageState extends State<PhraseImage> {
  String? _resolvedPath;

  @override
  void initState() {
    super.initState();
    _resolvedPath = _syncResolvedPath();
    _resolvePath();
  }

  @override
  void didUpdateWidget(covariant PhraseImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _resolvedPath = _syncResolvedPath();
      _resolvePath();
    }
  }

  String? _syncResolvedPath() {
    return existingPhraseImagePath(widget.imagePath);
  }

  Future<void> _resolvePath() async {
    final raw = widget.imagePath?.trim();
    if (raw == null || raw.isEmpty) {
      if (mounted && _resolvedPath != null) {
        setState(() => _resolvedPath = null);
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
    final cached = cachedPhraseImagePathSync(raw);
    if (cached != null) {
      if (mounted && _resolvedPath != cached) {
        setState(() => _resolvedPath = cached);
      }
      return;
    }

    if (isRemotePhraseImagePath(raw)) {
      final local = await cachePhraseImageLocally(raw);
      if (!mounted) return;
      if (local != null && local != raw && _resolvedPath != local) {
        setState(() => _resolvedPath = local);
      } else if (_resolvedPath == null) {
        setState(() => _resolvedPath = local ?? raw);
      }
      return;
    }

    if (mounted && _resolvedPath != raw) {
      setState(() => _resolvedPath = raw);
    }
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
    if (widget.fill) {
      return SizedBox.expand(child: _buildImage());
    }
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: _buildImage(),
    );
  }

  Widget _buildImage() {
    final raw = widget.imagePath?.trim();
    if (raw == null || raw.isEmpty) return _placeholder();

    final path = _resolvedPath ?? existingPhraseImagePath(raw) ?? raw;
    final lower = path.toLowerCase();
    if (lower.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _placeholder(),
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
          return _resolvedPath != null && !isRemotePhraseImagePath(_resolvedPath!)
              ? child
              : _placeholder();
        },
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (frame != null) {
            _cacheAfterNetworkLoad(raw);
          }
          if (wasSynchronouslyLoaded || frame != null) return child;
          return _resolvedPath != null && !isRemotePhraseImagePath(_resolvedPath!)
              ? child
              : _placeholder();
        },
        errorBuilder: (_, _, _) => _placeholder(),
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
          errorBuilder: (_, _, _) => _placeholder(),
        );
      }
    }

    return _placeholder();
  }

  Widget _placeholder() {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 40,
          color: widget.theme.textMain.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
