import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_spacing.dart';
import '../core/l10n/app_strings.dart';
import '../providers/app_state.dart';

/// Collects a new category name, saves it, and returns the new category key.
/// Owns its [TextEditingController] and disposes it when the route is removed.
class AddCategoryDialog extends StatefulWidget {
  const AddCategoryDialog({super.key});

  /// Returns the selected category key after a successful add, or null if cancelled.
  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const AddCategoryDialog(),
    );
  }

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;

    final app = context.read<AppState>();
    final lang = app.language;
    final name = _controller.text.trim();

    if (name.isEmpty) {
      setState(() => _error = AppStrings.fillAllFields(lang));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final error = await app.addCategory(name);
    if (!mounted) return;

    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }

    Navigator.of(context).pop(app.selectedCategoryKey);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final lang = app.language;
    final theme = app.theme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppStrings.newCategory(lang),
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: theme.textMain,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppStrings.chooseCategorySub(lang),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: theme.textMain.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  enabled: !_busy,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  decoration: InputDecoration(
                    hintText: AppStrings.categoryNameHint(lang),
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 13,
                      color: theme.textMain.withValues(alpha: 0.45),
                    ),
                    filled: true,
                    fillColor: theme.bgMid.withValues(alpha: 0.28),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: theme.bgAccent.withValues(alpha: 0.8),
                        width: 1.6,
                      ),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _error!,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFFC62828),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          side: BorderSide(
                            color: theme.bgAccent.withValues(alpha: 0.45),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          AppStrings.cancel(lang),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: theme.textMain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          backgroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _busy
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                AppStrings.add(lang),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
