import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_spacing.dart';
import '../core/theme/theme_tokens.dart';

/// Dropdown field with lesson-progress styling. [overlayMenu] floats the list
/// above surrounding content instead of expanding the parent layout.
class InlineDropdownField<T> extends StatefulWidget {
  const InlineDropdownField({
    super.key,
    this.label,
    required this.value,
    required this.options,
    required this.optionLabel,
    required this.selected,
    required this.theme,
    required this.onSelected,
    this.maxMenuHeight = 180,
    this.overlayMenu = false,
    this.isOpen,
    this.onToggle,
    this.valueFontSize = 13,
    this.optionFontSize = 13,
    this.triggerPadding,
    this.iconSize = 20,
    this.fieldBorderRadius = 10,
    this.triggerBackgroundColor,
    this.idleBorderColor,
    this.triggerBoxShadow,
  });

  final String? label;
  final String? value;
  final List<T> options;
  final String Function(T) optionLabel;
  final T? selected;
  final TapTalkThemeToken theme;
  final ValueChanged<T> onSelected;
  final double maxMenuHeight;
  final bool overlayMenu;
  final bool? isOpen;
  final VoidCallback? onToggle;
  final double valueFontSize;
  final double optionFontSize;
  final EdgeInsets? triggerPadding;
  final double iconSize;
  final double fieldBorderRadius;
  final Color? triggerBackgroundColor;
  final Color? idleBorderColor;
  final List<BoxShadow>? triggerBoxShadow;

  @override
  State<InlineDropdownField<T>> createState() => _InlineDropdownFieldState<T>();
}

class _InlineDropdownFieldState<T> extends State<InlineDropdownField<T>> {
  static const _borderColor = Color(0xFFE9EEF2);

  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _overlayOpen = false;

  bool get _menuOpen =>
      widget.overlayMenu ? _overlayOpen : (widget.isOpen ?? false);

  @override
  void didUpdateWidget(covariant InlineDropdownField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.overlayMenu &&
        oldWidget.selected != widget.selected &&
        _overlayOpen) {
      _removeOverlay();
    }
    if (!widget.overlayMenu &&
        oldWidget.isOpen == true &&
        widget.isOpen != true) {
      _removeOverlay();
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (_overlayOpen) {
      _overlayOpen = false;
    }
  }

  void _handleToggle() {
    if (widget.options.isEmpty) return;
    if (widget.overlayMenu) {
      if (_overlayOpen) {
        setState(_removeOverlay);
      } else {
        setState(() => _overlayOpen = true);
        _showOverlay();
      }
      return;
    }
    widget.onToggle?.call();
  }

  void _handleSelected(T option) {
    if (widget.overlayMenu) {
      setState(_removeOverlay);
    }
    widget.onSelected(option);
  }

  void _showOverlay() {
    final overlay = Overlay.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final fieldWidth = box?.size.width;

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (mounted) {
                    setState(_removeOverlay);
                  } else {
                    _removeOverlay();
                  }
                },
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 2),
              child: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: fieldWidth,
                  child: _DropdownMenuPanel<T>(
                    options: widget.options,
                    optionLabel: widget.optionLabel,
                    selected: widget.selected,
                    theme: widget.theme,
                    maxMenuHeight: widget.maxMenuHeight,
                    borderRadius: BorderRadius.circular(widget.fieldBorderRadius),
                    optionFontSize: widget.optionFontSize,
                    onSelected: _handleSelected,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final fieldRadius = BorderRadius.circular(widget.fieldBorderRadius);
    final openFieldRadius = const BorderRadius.only(
      topLeft: Radius.circular(10),
      topRight: Radius.circular(10),
    );
    final menuRadius = const BorderRadius.only(
      bottomLeft: Radius.circular(10),
      bottomRight: Radius.circular(10),
    );

    final trigger = _DropdownTrigger(
      label: widget.label,
      value: widget.value,
      isOpen: _menuOpen,
      theme: widget.theme,
      borderRadius: widget.overlayMenu || !_menuOpen
          ? fieldRadius
          : openFieldRadius,
      borderColor: _menuOpen
          ? widget.theme.bgAccent.withValues(alpha: 0.35)
          : (widget.idleBorderColor ?? _borderColor),
      onTap: _handleToggle,
      enabled: widget.options.isNotEmpty,
      valueFontSize: widget.valueFontSize,
      triggerPadding: widget.triggerPadding,
      iconSize: widget.iconSize,
      backgroundColor: widget.triggerBackgroundColor,
      boxShadow: widget.triggerBoxShadow,
    );

    if (widget.overlayMenu) {
      return CompositedTransformTarget(
        link: _layerLink,
        child: trigger,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        trigger,
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          clipBehavior: Clip.hardEdge,
          child: _menuOpen
              ? _DropdownMenuPanel<T>(
                  options: widget.options,
                  optionLabel: widget.optionLabel,
                  selected: widget.selected,
                  theme: widget.theme,
                  maxMenuHeight: widget.maxMenuHeight,
                  borderRadius: menuRadius,
                  optionFontSize: widget.optionFontSize,
                  onSelected: _handleSelected,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _DropdownTrigger extends StatelessWidget {
  const _DropdownTrigger({
    required this.label,
    required this.value,
    required this.isOpen,
    required this.theme,
    required this.borderRadius,
    required this.borderColor,
    required this.onTap,
    required this.enabled,
    this.valueFontSize = 13,
    this.triggerPadding,
    this.iconSize = 20,
    this.backgroundColor,
    this.boxShadow,
  });

  final String? label;
  final String? value;
  final bool isOpen;
  final TapTalkThemeToken theme;
  final BorderRadius borderRadius;
  final Color borderColor;
  final VoidCallback onTap;
  final bool enabled;
  final double valueFontSize;
  final EdgeInsets? triggerPadding;
  final double iconSize;
  final Color? backgroundColor;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final fillColor = backgroundColor ?? theme.bgMid.withValues(alpha: 0.35);

    final field = Material(
      color: fillColor,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: borderRadius,
        child: Container(
          padding: triggerPadding ??
              const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm + 2,
                vertical: AppSpacing.xs + 2,
              ),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (label != null && label!.isNotEmpty) ...[
                      Text(
                        label!,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: theme.textMain.withValues(alpha: 0.52),
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 1),
                    ],
                    Text(
                      value ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: valueFontSize,
                        fontWeight: FontWeight.w600,
                        color: theme.textMain,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: iconSize,
                  color: theme.textMain.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (boxShadow == null || boxShadow!.isEmpty) {
      return field;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: boxShadow,
      ),
      child: field,
    );
  }
}

class _DropdownMenuPanel<T> extends StatelessWidget {
  const _DropdownMenuPanel({
    required this.options,
    required this.optionLabel,
    required this.selected,
    required this.theme,
    required this.maxMenuHeight,
    required this.borderRadius,
    required this.onSelected,
    this.optionFontSize = 13,
  });

  final List<T> options;
  final String Function(T) optionLabel;
  final T? selected;
  final TapTalkThemeToken theme;
  final double maxMenuHeight;
  final BorderRadius borderRadius;
  final ValueChanged<T> onSelected;
  final double optionFontSize;

  static const _borderColor = Color(0xFFE9EEF2);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: theme.textMain.withValues(alpha: 0.12),
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.bgAccent.withValues(alpha: 0.35),
          ),
          borderRadius: borderRadius,
        ),
        constraints: BoxConstraints(maxHeight: maxMenuHeight),
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < options.length; index++) ...[
                if (index > 0) const Divider(height: 1, color: _borderColor),
                _DropdownOptionTile(
                  label: optionLabel(options[index]),
                  isSelected: options[index] == selected,
                  theme: theme,
                  fontSize: optionFontSize,
                  onTap: () => onSelected(options[index]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownOptionTile extends StatelessWidget {
  const _DropdownOptionTile({
    required this.label,
    required this.isSelected,
    required this.theme,
    required this.onTap,
    this.fontSize = 13,
  });

  final String label;
  final bool isSelected;
  final TapTalkThemeToken theme;
  final VoidCallback onTap;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: fontSize,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? theme.bgAccent : theme.textMain,
                  height: 1.25,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_rounded,
                color: theme.bgAccent,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
