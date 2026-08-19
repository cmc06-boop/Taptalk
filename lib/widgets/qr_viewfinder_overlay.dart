import 'dart:ui';

import 'package:flutter/material.dart';

/// Scan window size used across the QR scanner layout.
const double kQrScanCutoutSize = 260;

/// Full-screen dim/blur mask outside the scan window, with a clean border frame.
class QrScanMaskOverlay extends StatelessWidget {
  const QrScanMaskOverlay({
    super.key,
    required this.cutoutRect,
    this.borderRadius = 14,
    this.blurSigma = 6,
    this.dimOpacity = 0.52,
  });

  final Rect? cutoutRect;
  final double borderRadius;
  final double blurSigma;
  final double dimOpacity;

  @override
  Widget build(BuildContext context) {
    final rect = cutoutRect;
    if (rect == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipPath(
            clipper: _OutsideRoundedRectClipper(
              rect: rect,
              radius: borderRadius,
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blurSigma,
                sigmaY: blurSigma,
              ),
              child: Container(
                color: Colors.black.withValues(alpha: dimOpacity),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: rect,
            child: CustomPaint(
              painter: _ScanFramePainter(
                color: Colors.white,
                borderRadius: borderRadius,
                strokeWidth: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutsideRoundedRectClipper extends CustomClipper<Path> {
  const _OutsideRoundedRectClipper({
    required this.rect,
    required this.radius,
  });

  final Rect rect;
  final double radius;

  @override
  Path getClip(Size size) {
    return Path.combine(
      PathOperation.difference,
      Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
      Path()
        ..addRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        ),
    );
  }

  @override
  bool shouldReclip(covariant _OutsideRoundedRectClipper oldClipper) {
    return oldClipper.rect != rect || oldClipper.radius != radius;
  }
}

class _ScanFramePainter extends CustomPainter {
  const _ScanFramePainter({
    required this.color,
    required this.borderRadius,
    required this.strokeWidth,
  });

  final Color color;
  final double borderRadius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
