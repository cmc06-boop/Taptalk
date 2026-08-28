import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/constants/app_spacing.dart';
import '../core/theme/theme_tokens.dart';
import '../core/utils/phrase_image_storage.dart';
import 'phrase_image.dart';

/// Compact image/video thumb inside the composer text field, with a corner X.
class ComposerAttachmentPreview extends StatelessWidget {
  const ComposerAttachmentPreview({
    super.key,
    required this.path,
    required this.onRemove,
    this.theme,
    this.width,
    this.height,
  });

  final String path;
  final VoidCallback onRemove;
  final TapTalkThemeToken? theme;
  final double? width;
  final double? height;

  static const double _size = 64;

  @override
  Widget build(BuildContext context) {
    final preview = SizedBox(
      width: width ?? _size,
      height: height ?? _size,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: ColoredBox(
                color: const Color(0xFFF0F0F0),
                child: _media(),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 1,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const SizedBox(
                  width: 22,
                  height: 22,
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (width != null) return preview;
    return Align(alignment: Alignment.centerLeft, child: preview);
  }

  Widget _media() {
    if (isPhraseVideoPath(path)) {
      return _ComposerVideoThumb(path: path, theme: theme);
    }
    if (path.toLowerCase().startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Center(
          child: Icon(Icons.broken_image_outlined),
        ),
      );
    }
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Center(
          child: Icon(Icons.broken_image_outlined),
        ),
      );
    }
    final fallbackTheme = theme;
    if (fallbackTheme != null) {
      return PhraseImage(imagePath: path, theme: fallbackTheme, fill: true);
    }
    return const Center(child: Icon(Icons.broken_image_outlined));
  }
}

class _ComposerVideoThumb extends StatefulWidget {
  const _ComposerVideoThumb({required this.path, this.theme});

  final String path;
  final TapTalkThemeToken? theme;

  @override
  State<_ComposerVideoThumb> createState() => _ComposerVideoThumbState();
}

class _ComposerVideoThumbState extends State<_ComposerVideoThumb> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final raw = widget.path;
    final VideoPlayerController controller;
    if (raw.toLowerCase().startsWith('assets/')) {
      controller = VideoPlayerController.asset(raw);
    } else {
      final resolved =
          existingPhraseImagePath(raw) ??
          cachedPhraseImagePathSync(raw) ??
          raw;
      if (!File(resolved).existsSync()) {
        return;
      }
      controller = VideoPlayerController.file(File(resolved));
    }
    _controller = controller;
    controller.setVolume(0);
    controller.initialize().then((_) {
      if (!mounted) return;
      controller.pause();
      setState(() => _ready = true);
    }).catchError((_) {
      if (mounted) setState(() => _ready = false);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_ready && controller != null && controller.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      );
    }
    final theme = widget.theme;
    if (theme != null) {
      return PhraseImage(
        imagePath: widget.path,
        theme: theme,
        fill: true,
      );
    }
    return const Center(child: Icon(Icons.videocam_rounded));
  }
}
