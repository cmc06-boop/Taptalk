import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/navigation/route_transitions.dart';
import '../core/l10n/app_strings.dart';
import '../core/utils/code_qr_utils.dart';
import '../providers/app_state.dart';
import 'code_manual_entry_sheet.dart';
import 'qr_viewfinder_overlay.dart';

enum QrScanKind { classCode, profileCode }

typedef CodeSubmitHandler = Future<String?> Function(String code);

/// Scan-first flow with manual entry fallback at the bottom.
class CodeScanFlowScreen extends StatefulWidget {
  const CodeScanFlowScreen({
    super.key,
    required this.kind,
    required this.title,
    required this.scanHint,
    required this.manualTitle,
    required this.manualHint,
    required this.manualHintText,
    required this.onSubmit,
  });

  final QrScanKind kind;
  final String title;
  final String scanHint;
  final String manualTitle;
  final String manualHint;
  final String manualHintText;
  final CodeSubmitHandler onSubmit;

  static Future<bool> open(
    BuildContext context, {
    required QrScanKind kind,
    required String title,
    required String scanHint,
    required String manualTitle,
    required String manualHint,
    required String manualHintText,
    required CodeSubmitHandler onSubmit,
  }) async {
    final lang = context.read<AppState>().language;
    if (!CodeQrUtils.isScanSupported) {
      final code = await CodeManualEntrySheet.show(
        context,
        title: manualTitle,
        hint: manualHint,
        hintText: manualHintText,
      );
      if (code == null || !context.mounted) return false;
      final error = await onSubmit(code);
      if (!context.mounted) return false;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
        return false;
      }
      return true;
    }

    if (!await ensureCameraPermission(lang)) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.cameraPermissionRequired(lang))),
      );
      return false;
    }
    if (!context.mounted) return false;

    final result = await Navigator.of(context).push<bool>(
      taptalkPageRoute(
        builder: (_) => CodeScanFlowScreen(
          kind: kind,
          title: title,
          scanHint: scanHint,
          manualTitle: manualTitle,
          manualHint: manualHint,
          manualHintText: manualHintText,
          onSubmit: onSubmit,
        ),
      ),
    );
    return result ?? false;
  }

  @override
  State<CodeScanFlowScreen> createState() => _CodeScanFlowScreenState();
}

class _CodeScanFlowScreenState extends State<CodeScanFlowScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  final _scanWindowKey = GlobalKey();
  bool _handled = false;
  bool _busy = false;
  String? _error;
  bool _torchOn = false;
  Rect? _cutoutRect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncCutoutRect());
  }

  void _syncCutoutRect() {
    final box = _scanWindowKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !mounted) return;
    final topLeft = box.localToGlobal(Offset.zero);
    final next = topLeft & box.size;
    if (_cutoutRect == next) return;
    setState(() => _cutoutRect = next);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _extractCode(String raw) {
    return widget.kind == QrScanKind.classCode
        ? CodeQrUtils.extractClassCode(raw)
        : CodeQrUtils.extractProfileCode(raw);
  }

  Future<void> _completeWithCode(String code) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onSubmit(code);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _handled = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || _busy || !mounted) return;
    final lang = context.read<AppState>().language;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw == null || raw.isEmpty) continue;
      final code = _extractCode(raw);
      if (code == null) {
        setState(() => _error = AppStrings.qrCodeNotRecognized(lang));
        continue;
      }
      _handled = true;
      _completeWithCode(code);
      return;
    }
  }

  Future<void> _openManualEntry() async {
    if (_busy) return;
    final code = await CodeManualEntrySheet.show(
      context,
      title: widget.manualTitle,
      hint: widget.manualHint,
      hintText: widget.manualHintText,
    );
    if (!mounted || code == null) return;
    _handled = true;
    await _completeWithCode(code);
  }

  Future<void> _pickQrFromGallery() async {
    if (_busy) return;
    final lang = context.read<AppState>().language;
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final result = await _controller.analyzeImage(picked.path);
      if (!mounted) return;
      if (result == null || result.barcodes.isEmpty) {
        setState(() {
          _busy = false;
          _error = AppStrings.noQrFoundInImage(lang);
        });
        return;
      }
      for (final barcode in result.barcodes) {
        final raw = barcode.rawValue?.trim();
        if (raw == null || raw.isEmpty) continue;
        final code = _extractCode(raw);
        if (code == null) {
          setState(() {
            _busy = false;
            _error = AppStrings.qrCodeNotRecognized(lang);
          });
          return;
        }
        _handled = true;
        await _completeWithCode(code);
        return;
      }
      setState(() {
        _busy = false;
        _error = AppStrings.noQrFoundInImage(lang);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = AppStrings.noQrFoundInImage(lang);
      });
    }
  }

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    if (!mounted) return;
    setState(() => _torchOn = !_torchOn);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncCutoutRect());
    final app = context.watch<AppState>();
    final lang = app.language;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          QrScanMaskOverlay(cutoutRect: _cutoutRect),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    0,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 48),
                      Expanded(
                        child: Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _busy ? null : _toggleTorch,
                        icon: Icon(
                          _torchOn
                              ? Icons.flashlight_on_rounded
                              : Icons.flashlight_off_rounded,
                        ),
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  AppStrings.scanQrCode(lang),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  key: _scanWindowKey,
                  width: kQrScanCutoutSize,
                  height: kQrScanCutoutSize,
                ),
                const SizedBox(height: AppSpacing.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: Text(
                    _error ?? widget.scanHint,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: _error != null
                          ? const Color(0xFFFF8A80)
                          : Colors.white.withValues(alpha: 0.72),
                      height: 1.35,
                    ),
                  ),
                ),
                const Spacer(),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.lg),
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _pickQrFromGallery,
                          icon: const Icon(Icons.image_outlined, size: 20),
                          label: Text(
                            AppStrings.uploadQrImage(lang),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1A1A1A),
                            disabledBackgroundColor:
                                Colors.white.withValues(alpha: 0.55),
                            disabledForegroundColor:
                                const Color(0xFF1A1A1A).withValues(alpha: 0.45),
                            elevation: 0,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _busy ? null : _openManualEntry,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                              color: Colors.white54,
                              width: 1.5,
                            ),
                            disabledForegroundColor:
                                Colors.white.withValues(alpha: 0.45),
                            elevation: 0,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            AppStrings.enterCodeManually(lang),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> ensureCameraPermission(AppLanguage lang) async {
  if (!CodeQrUtils.isScanSupported) return false;
  var status = await Permission.camera.status;
  if (status.isGranted) return true;
  status = await Permission.camera.request();
  return status.isGranted;
}
