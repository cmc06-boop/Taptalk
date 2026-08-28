import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_scanner/mobile_scanner.dart' hide BarcodeFormat;
import 'package:zxing2/qrcode.dart';

/// Decodes a QR from a gallery image, including camera photos of a phone
/// screen (screenshots already work with ML Kit; photos often need extra
/// contrast / a second decoder).
Future<String?> decodeQrFromGalleryImage({
  required MobileScannerController controller,
  required String path,
}) async {
  final fromScanner = await _analyzeWithScanner(controller, path);
  if (fromScanner != null) return fromScanner;

  Uint8List bytes;
  try {
    bytes = await File(path).readAsBytes();
  } catch (_) {
    return null;
  }
  if (bytes.isEmpty) return null;

  _PreparedGalleryQr prepared;
  try {
    prepared = await compute(_prepareGalleryQrImage, bytes);
  } catch (e, st) {
    debugPrint('Gallery QR decode failed: $e\n$st');
    return null;
  }
  if (prepared.text != null && prepared.text!.isNotEmpty) {
    return prepared.text;
  }

  final jpeg = prepared.jpeg;
  if (jpeg == null || jpeg.isEmpty) return null;
  final tmp = File(
    '${Directory.systemTemp.path}/taptalk_qr_${DateTime.now().millisecondsSinceEpoch}.jpg',
  );
  try {
    await tmp.writeAsBytes(jpeg, flush: true);
    return await _analyzeWithScanner(controller, tmp.path);
  } catch (e, st) {
    debugPrint('Prepared gallery QR failed: $e\n$st');
    return null;
  } finally {
    try {
      await tmp.delete();
    } catch (_) {}
  }
}

Future<String?> _analyzeWithScanner(
  MobileScannerController controller,
  String path,
) async {
  try {
    final result = await controller
        .analyzeImage(path)
        .timeout(const Duration(seconds: 8), onTimeout: () => null);
    return _firstRawValue(result);
  } catch (e, st) {
    debugPrint('ML Kit gallery QR failed: $e\n$st');
    return null;
  }
}

String? _firstRawValue(BarcodeCapture? capture) {
  if (capture == null) return null;
  for (final barcode in capture.barcodes) {
    final raw = barcode.rawValue?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
  }
  return null;
}

class _PreparedGalleryQr {
  const _PreparedGalleryQr({this.text, this.jpeg});

  final String? text;
  final Uint8List? jpeg;
}

_PreparedGalleryQr _prepareGalleryQrImage(Uint8List bytes) {
  var decoded = img.decodeImage(bytes);
  if (decoded == null) return const _PreparedGalleryQr();
  decoded = img.bakeOrientation(decoded);
  final sized = _shrinkForScan(decoded);

  for (final variant in _scanVariants(sized)) {
    final text = _zxingRead(variant);
    if (text != null) return _PreparedGalleryQr(text: text);
  }

  final contrast = img.adjustColor(
    img.Image.from(sized),
    contrast: 1.8,
    saturation: 0,
  );
  final jpeg = img.encodeJpg(contrast, quality: 95);
  return _PreparedGalleryQr(jpeg: Uint8List.fromList(jpeg));
}

img.Image _shrinkForScan(img.Image src) {
  const maxSide = 1800;
  final longest = src.width > src.height ? src.width : src.height;
  if (longest <= maxSide) return src;
  if (src.width >= src.height) {
    return img.copyResize(
      src,
      width: maxSide,
      interpolation: img.Interpolation.linear,
    );
  }
  return img.copyResize(
    src,
    height: maxSide,
    interpolation: img.Interpolation.linear,
  );
}

List<img.Image> _scanVariants(img.Image src) {
  final variants = <img.Image>[src];

  final contrast = img.adjustColor(
    img.Image.from(src),
    contrast: 1.7,
    saturation: 0,
  );
  variants.add(contrast);
  variants.add(img.invert(img.Image.from(contrast)));

  if (src.width > 80 && src.height > 80) {
    final cropW = (src.width * 0.78).round();
    final cropH = (src.height * 0.78).round();
    variants.add(
      img.copyCrop(
        src,
        x: ((src.width - cropW) / 2).round(),
        y: ((src.height - cropH) / 2).round(),
        width: cropW,
        height: cropH,
      ),
    );
  }

  final longest = src.width > src.height ? src.width : src.height;
  if (longest < 900) {
    variants.add(
      img.copyResize(
        src,
        width: src.width * 2,
        height: src.height * 2,
        interpolation: img.Interpolation.nearest,
      ),
    );
  }

  return variants;
}

String? _zxingRead(img.Image image) {
  final pixels = Int32List(image.width * image.height);
  var i = 0;
  for (final pixel in image) {
    final max = pixel.maxChannelValue == 0 ? 255 : pixel.maxChannelValue;
    final r = ((pixel.r * 255) / max).round().clamp(0, 255);
    final g = ((pixel.g * 255) / max).round().clamp(0, 255);
    final b = ((pixel.b * 255) / max).round().clamp(0, 255);
    pixels[i++] = (r << 16) | (g << 8) | b;
  }

  final source = RGBLuminanceSource(image.width, image.height, pixels);
  final hints = DecodeHints()
    ..put(DecodeHintType.tryHarder)
    ..put(DecodeHintType.possibleFormats, [BarcodeFormat.qrCode]);
  final reader = QRCodeReader();

  for (final binarizer in [
    HybridBinarizer(source),
    GlobalHistogramBinarizer(source),
  ]) {
    try {
      final result = reader.decode(
        BinaryBitmap(binarizer),
        hints: hints,
      );
      final text = result.text.trim();
      if (text.isNotEmpty) return text;
    } catch (_) {}
  }
  return null;
}
