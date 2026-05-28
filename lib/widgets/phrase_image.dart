import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/theme/theme_tokens.dart';

/// Displays a phrase image from network URL, asset, or local file path.
class PhraseImage extends StatelessWidget {
  const PhraseImage({
    super.key,
    required this.imagePath,
    required this.theme,
    this.aspectRatio = 1.35,
  });

  final String? imagePath;
  final TapTalkThemeToken theme;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: _buildImage(),
    );
  }

  Widget _buildImage() {
    final path = imagePath?.trim();
    if (path == null || path.isEmpty) return _placeholder();

    final lower = path.toLowerCase();
    if (lower.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
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
        headers: const {'User-Agent': 'TapTalk/1.0'},
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _loading();
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
          errorBuilder: (_, _, _) => _placeholder(),
        );
      }
    }

    return _placeholder();
  }

  Widget _loading() {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: theme.bgAccent,
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 40,
          color: theme.textMain.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
